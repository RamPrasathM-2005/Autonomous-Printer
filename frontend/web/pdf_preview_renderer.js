window.renderPdfToCanvas = function(canvasId, base64Data, pageNumber) {
    if (typeof pdfjsLib === 'undefined') {
        console.warn('PDF.js library is not loaded');
        return;
    }
    pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
    
    try {
        var raw = atob(base64Data);
        var uint8Array = new Uint8Array(raw.length);
        for (var i = 0; i < raw.length; i++) {
            uint8Array[i] = raw.charCodeAt(i);
        }
        var loadingTask = pdfjsLib.getDocument({data: uint8Array});
        loadingTask.promise.then(function(pdf) {
            var targetPage = Math.min(Math.max(1, pageNumber || 1), pdf.numPages);
            pdf.getPage(targetPage).then(function(page) {
                var canvas = document.getElementById(canvasId);
                if (!canvas) return;
                var context = canvas.getContext('2d');
                var viewport = page.getViewport({scale: 1.2});
                canvas.height = viewport.height;
                canvas.width = viewport.width;
                canvas.style.width = '100%';
                canvas.style.height = 'auto';
                canvas.style.maxHeight = '100%';
                canvas.style.objectFit = 'contain';
                var renderContext = {
                    canvasContext: context,
                    viewport: viewport
                };
                page.render(renderContext);
            });
        }).catch(function(err) {
            console.error('PDF rendering error:', err);
        });
    } catch(e) {
        console.error('Base64 decode error in PDF renderer:', e);
    }
};
