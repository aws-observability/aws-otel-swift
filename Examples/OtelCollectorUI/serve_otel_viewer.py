#!/usr/bin/env python3
import http.server
import socketserver
import os
import webbrowser
from pathlib import Path

class OTELHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

def main():
    port = 3000
    app_dir = Path(__file__).parent.parent
    
    # Change to the Examples directory to serve files
    os.chdir(app_dir)
    
    with socketserver.TCPServer(("", port), OTELHandler) as httpd:
        httpd.allow_reuse_address = True
        print(f"OTEL Timeline Viewer running at http://localhost:{port}")
        print(f"Open http://localhost:{port}/OtelCollectorUI/otel-timeline-viewer.html in your browser")
        print("Press Ctrl+C to stop the server")
        
        # Try to open browser automatically
        try:
            webbrowser.open(f'http://localhost:{port}/OtelCollectorUI/otel-timeline-viewer.html')
        except:
            pass
            
        httpd.serve_forever()

if __name__ == "__main__":
    main()