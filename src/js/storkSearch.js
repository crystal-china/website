import stork from "./stork.js";

let storkReadyPromise;

async function setupStork(root, assetUrl) {
    const selector = "input[data-stork='docs']";
    const input = root.matches(selector) ? root : root.querySelector(selector);

    if (input == null) {
        return;
    }

    try {
        storkReadyPromise ??= (async () => {
            await stork.initialize(await assetUrl("docs/stork.wasm"));
            await stork.downloadIndex("docs", await assetUrl("docs/index.st"));
        })();

        await storkReadyPromise;

        // 索引加载期间页面可能已被替换，只在 input 仍旧存在时才挂载。
        if (input.isConnected) {
            stork.attach("docs");
        }
    } catch (error) {
        storkReadyPromise = null;
        console.error("Failed to initialize Stork", error);
    }
}

export default setupStork;
