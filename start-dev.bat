@echo off
start "SignBridge Backend" cmd /k "cd /d %~dp0backend && .venv\Scripts\activate && python -m uvicorn app.main:app --reload"
timeout /t 5 >nul
start "SignBridge Frontend" cmd /k "cd /d %~dp0Frontend && flutter run -d chrome"
