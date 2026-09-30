"""Additive migration for existing MySQL installations; run while services are stopped."""
from sqlalchemy import inspect, text
from sqlalchemy.schema import CreateColumn, CreateIndex
from app.config.database import engine
from app.db.base import Base

ADDITIONS = {
    'documents': ['session_id'],
    'orders': ['session_id', 'request_key', 'request_hash'],
    'payments': ['creation_state', 'gateway_key_id', 'verified_at', 'reconciled_at', 'last_error'],
    'print_jobs': ['claim_token_hash', 'claimed_at'],
}

def migrate():
    Base.metadata.create_all(engine)
    with engine.begin() as connection:
        for table_name, names in ADDITIONS.items():
            known = {c['name'] for c in inspect(connection).get_columns(table_name)}
            table = Base.metadata.tables[table_name]
            for name in names:
                if name in known:
                    continue
                column = table.c[name]
                if name == 'creation_state':
                    ddl = "creation_state VARCHAR(24) NOT NULL DEFAULT 'LEGACY'"
                else:
                    ddl = str(CreateColumn(column).compile(dialect=engine.dialect))
                connection.execute(text(f'ALTER TABLE {table_name} ADD COLUMN {ddl}'))
            if engine.dialect.name == 'mysql' and table_name == 'payments':
                connection.execute(text('ALTER TABLE payments MODIFY razorpay_order_id VARCHAR(128) NULL'))
            known_indexes = {i['name'] for i in inspect(connection).get_indexes(table_name)}
            for index in table.indexes:
                if index.name not in known_indexes:
                    connection.execute(CreateIndex(index))
        # MySQL index for concurrent request idempotency on existing tables.
        if engine.dialect.name == 'mysql':
            indexes = inspect(connection).get_indexes('orders')
            if not any(i.get('unique') and i['column_names'] == ['request_key'] for i in indexes):
                connection.execute(text('CREATE UNIQUE INDEX uq_orders_request_key ON orders (request_key)'))
            for table_name in ('orders', 'documents'):
                fks = inspect(connection).get_foreign_keys(table_name)
                if not any(f['constrained_columns'] == ['session_id'] for f in fks):
                    connection.execute(text(f'ALTER TABLE {table_name} ADD CONSTRAINT fk_{table_name}_session '
                        'FOREIGN KEY (session_id) REFERENCES customer_sessions(id)'))
        connection.execute(text('CREATE TABLE IF NOT EXISTS schema_migrations '
                                '(version VARCHAR(64) PRIMARY KEY)'))
        exists = connection.scalar(text("SELECT version FROM schema_migrations WHERE version='secure_payments_v1'"))
        if not exists:
            # Old demo records remain for review, but never authorize a new print job.
            connection.execute(text('UPDATE otps SET active=0 WHERE order_id IN '
                                    '(SELECT id FROM orders WHERE session_id IS NULL)'))
            connection.execute(text("INSERT INTO schema_migrations(version) VALUES ('secure_payments_v1')"))
    print('Security schema migration completed; legacy records preserved and unverified.')

if __name__ == '__main__':
    migrate()
