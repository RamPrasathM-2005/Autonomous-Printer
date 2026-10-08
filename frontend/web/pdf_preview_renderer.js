(function() {
    window._activePdfRenderTasks = window._activePdfRenderTasks || {};

    function findElementInDomOrShadow(id) {
        var el = document.getElementById(id);
        if (el) return el;
        function search(root) {
            if (!root) return null;
            if (root.shadowRoot) {
                var found = root.shadowRoot.getElementById(id);
                if (found) return found;
                var deeper = search(root.shadowRoot);
                if (deeper) return deeper;
            }
            var children = root.children || [];
            for (var i = 0; i < children.length; i++) {
                var res = search(children[i]);
                if (res) return res;
            }
            return null;
        }
        return search(document.body);
    }

    window.renderPdfToCanvas = function(canvasId, base64Data, pageNumber, retryCount) {
        retryCount = (typeof retryCount === 'number') ? retryCount : 15;

        if (typeof pdfjsLib === 'undefined') {
            if (retryCount > 0) {
                setTimeout(function() {
                    window.renderPdfToCanvas(canvasId, base64Data, pageNumber, retryCount - 1);
                }, 100);
            } else {
                console.warn('PDF.js library is not loaded');
            }
            return;
        }

        try {
            pdfjsLib.GlobalWorkerOptions.workerSrc = new URL('vendor/pdfjs/pdf.worker.min.mjs', document.baseURI).href;
        } catch (_) {}

        var canvas = findElementInDomOrShadow(canvasId);
        if (!canvas) {
            if (retryCount > 0) {
                setTimeout(function() {
                    window.renderPdfToCanvas(canvasId, base64Data, pageNumber, retryCount - 1);
                }, 100);
            }
            return;
        }

        try {
            var raw = atob(base64Data);
            var uint8Array = new Uint8Array(raw.length);
            for (var i = 0; i < raw.length; i++) {
                uint8Array[i] = raw.charCodeAt(i);
            }

            var loadingTask = pdfjsLib.getDocument({
                data: uint8Array,
                isEvalSupported: false,
                enableScripting: false,
                disableRange: true,
                disableStream: true
            });

            loadingTask.promise.then(function(pdf) {
                var targetPage = Math.min(Math.max(1, pageNumber || 1), pdf.numPages);
                pdf.getPage(targetPage).then(function(page) {
                    var targetCanvas = findElementInDomOrShadow(canvasId);
                    if (!targetCanvas) return;

                    var context = targetCanvas.getContext('2d');
                    var viewport = page.getViewport({ scale: 1.5 });
                    var pixelCount = viewport.width * viewport.height;
                    if (!Number.isFinite(pixelCount) || pixelCount <= 0) {
                        throw new Error('Invalid PDF page dimensions');
                    }
                    var reduction = Math.min(1, 8192 / viewport.width, 8192 / viewport.height,
                        Math.sqrt(16000000 / pixelCount));
                    if (reduction < 1) viewport = page.getViewport({ scale: 1.5 * reduction });

                    // Cancel any active render task on this canvas before starting a new one
                    if (window._activePdfRenderTasks[canvasId]) {
                        try {
                            window._activePdfRenderTasks[canvasId].cancel();
                        } catch (_) {}
                        delete window._activePdfRenderTasks[canvasId];
                    }

                    targetCanvas.height = viewport.height;
                    targetCanvas.width = viewport.width;
                    targetCanvas.style.width = '100%';
                    targetCanvas.style.height = 'auto';
                    targetCanvas.style.maxHeight = '100%';
                    targetCanvas.style.objectFit = 'contain';

                    context.clearRect(0, 0, targetCanvas.width, targetCanvas.height);

                    var renderContext = {
                        canvasContext: context,
                        viewport: viewport
                    };

                    var renderTask = page.render(renderContext);
                    window._activePdfRenderTasks[canvasId] = renderTask;

                    renderTask.promise.then(function() {
                        if (window._activePdfRenderTasks[canvasId] === renderTask) {
                            delete window._activePdfRenderTasks[canvasId];
                        }
                    }).catch(function(err) {
                        if (window._activePdfRenderTasks[canvasId] === renderTask) {
                            delete window._activePdfRenderTasks[canvasId];
                        }
                        if (err && err.name === 'RenderingCancelledException') {
                            return; // Expected cancellation when switching pages
                        }
                        console.error('PDF rendering error:', err);
                    });
                });
            }).catch(function(err) {
                console.error('PDF document load error:', err);
            });
        } catch (e) {
            console.error('Base64 decode error in PDF renderer:', e);
        }
    };
})();
