from unittest.mock import Mock
import pytest
from app.services.printer_health import observe, reachable, _cache
from app.services.printer_discovery import PrinterDiscovery
from app.services.cups_service import CupsService


def test_processing_queue_with_disconnected_device_is_offline(monkeypatch):
    monkeypatch.setattr('app.services.printer_health.reachable', lambda *args: False)
    assert observe({'device-uri': 'ipp://192.0.2.1/ipp/print', 'printer-state': 4})[0] == 'OFFLINE'


@pytest.mark.parametrize('reason,state', [('media-empty-warning', 'OUT_OF_PAPER'), ('media-jam-error', 'ERROR'), ('door-open-error', 'ERROR'), ('connecting-to-device', 'OFFLINE')])
def test_printer_reasons_override_busy(monkeypatch, reason, state):
    monkeypatch.setattr('app.services.printer_health.reachable', lambda *args: True)
    assert observe({'printer-state': 4, 'printer-state-reasons': [reason]})[0] == state


def test_tcp_probe_is_bounded_and_offline_is_cached(monkeypatch):
    _cache.clear()
    connect = Mock(side_effect=TimeoutError())
    monkeypatch.setattr('socket.create_connection', connect)
    assert reachable('ipp://192.0.2.1/ipp/print') is False
    assert reachable('ipp://192.0.2.1/ipp/print') is False
    assert connect.call_count == 1
    assert connect.call_args.kwargs['timeout'] == 1.5


def test_uninstalled_advertised_printer_is_discovered_and_mapping_provisions(monkeypatch):
    run = Mock(return_value=Mock(stdout='HP Test\tipp://hp.local:631/ipp/print\n', returncode=0))
    monkeypatch.setattr('app.services.printer_discovery.subprocess.run', run)
    monkeypatch.setattr('socket.gethostbyname', lambda host: '192.0.2.7')
    discovery = PrinterDiscovery()
    printer = discovery.scan()[0]
    assert printer['status'] == 'DISCOVERED'
    assert printer['device_uri'] == 'ipp://192.0.2.7/ipp/print'
    assert run.call_count == 1  # Discovery itself creates no queue.
    discovery.provision([printer], set())
    assert run.call_args.args[0][0] == '/usr/sbin/lpadmin'
    assert printer['device_uri'] in run.call_args.args[0]
    discovery.provision([printer], {printer['cups_printer_name']})
    assert run.call_count == 2


def test_arbitrary_server_assignment_cannot_configure_undiscovered_device(monkeypatch):
    run = Mock()
    monkeypatch.setattr('app.services.printer_discovery.subprocess.run', run)
    PrinterDiscovery().provision([{'cups_printer_name': 'bad', 'device_uri': 'file:/dev/null'}], set())
    run.assert_not_called()


def test_existing_offline_job_reports_pause_then_completion_without_resubmit(monkeypatch):
    service = CupsService()
    service.has_pycups = True
    service.mock_mode = False
    service.cups = Mock()
    conn = service.cups.Connection.return_value
    conn.getJobAttributes.side_effect = [{'job-state': 5}, {'job-state': 9}]
    conn.getPrinterAttributes.return_value = {'device-uri': 'ipp://192.0.2.1/ipp/print', 'printer-state': 4}
    monkeypatch.setattr('app.services.printer_health.reachable', lambda *args: False)
    monkeypatch.setattr('time.sleep', lambda _: None)
    callback = Mock()
    assert service.monitor_job('6', on_status_callback=callback, target_printer='HP') == 'COMPLETED'
    assert callback.call_args.kwargs['error_code'] == 'OFFLINE'
    conn.printFile.assert_not_called()
