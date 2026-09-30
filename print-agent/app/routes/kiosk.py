from flask import Blueprint, redirect, render_template, url_for
from app.config import config

kiosk_bp = Blueprint("kiosk", __name__)


@kiosk_bp.get("/kiosk")
def render_kiosk():
    return render_template("kiosk.html", agent_id=config.AGENT_ID, mock_printing=config.MOCK_CUPS)


@kiosk_bp.get("/")
def index():
    return redirect(url_for("kiosk.render_kiosk"))
