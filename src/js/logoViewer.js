import Viewer3D from "./viewer3d.js";

async function setupLogo(root, assetUrl) {
    const selector = "#logo-canvas";
    const canvas = root.matches(selector) ? root : root.querySelector(selector);

    if (canvas != null && canvas.getAttribute("running") === "false") {
        // 在等待资源 URL 前先标记，避免并发的 HTMX callback
        // 为同一个 canvas 启动多个 Viewer3D。
        canvas.setAttribute("running", "true");

        // setIPhoneDataAttribute
        let platform = navigator?.userAgent || navigator?.platform || "unknown";

        if (/iPhone/.test(platform)) {
            document.documentElement.dataset.uaIphone = true;
        }

        // startLogoAnimation
        try {
            const modelUrl = await assetUrl("models/icosahedron.xml");

            if (canvas.isConnected) {
                const model = new Viewer3D(canvas);
                model.shader("flat", 255, 255, 255);
                model.insertModel(modelUrl);
                model.contrast(0.9);
            }
        } catch (error) {
            canvas.setAttribute("running", "false");
            console.error("Failed to initialize logo", error);
        }
    }
}

export default setupLogo;
