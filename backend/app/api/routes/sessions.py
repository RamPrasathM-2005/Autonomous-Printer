from fastapi import APIRouter, Depends, Request
from app.db.session import get_db
from app.services.access_service import create_session, current_session
from app.utils.common import now

router = APIRouter(prefix='/api/sessions', tags=['Customer sessions'])

@router.post('', status_code=201)
def start_session(request: Request, db=Depends(get_db)):
    return create_session(db, request)

@router.delete('/current')
def end_session(session=Depends(current_session), db=Depends(get_db)):
    session.expires_at = now()
    db.commit()
    return {'status': 'ended'}
