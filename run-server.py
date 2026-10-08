"""Server backend, refund worker and frontend; never starts a print agent."""
from scripts.project import main

if __name__ == "__main__":
    main(server=True)
