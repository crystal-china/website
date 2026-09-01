/* eslint no-console:0 */

import { initializeApp } from "firebase/app";
import { getAnalytics, logEvent } from "firebase/analytics";
import htmx from "htmx.org";
import "hyperscript.org";
// import * as AsciinemaPlayer from 'asciinema-player';
// AsciinemaPlayer.create('/demo.cast', document.getElementById('demo'));

import createAssetUrl from "./assetUrl.js";
import copyCodeButton from "./copyCodeButton.js";
import decodePromptTooltips from "./hxPromptDecoding.js";
import findElements from "./findElements.js";
import setupLogo from "./logoViewer.js";
import pasteImage from "./pasteImage.js";
import setupStork from "./storkSearch.js";

// 调试 HTMX 时临时取消注释；错误和警告默认始终输出。
// htmx.config.logAll = true;

  // HTMX 4 默认只允许同源请求；确实需要跨域并已配置 CORS 时取消注释。
  // htmx.config.mode = "cors";

const frontendConfig = JSON.parse(
    document.getElementById("app-config")?.textContent ?? "{}",
);
const assetHost = frontendConfig.assetHost ?? "";
const assetBasePath = frontendConfig.assetBasePath ?? "/assets";
const assetUrl = createAssetUrl(assetHost, assetBasePath);
const firebaseConfig = frontendConfig.firebaseConfig ?? {};

if (firebaseConfig.apiKey != null) {
    const app = initializeApp(firebaseConfig);
    const analytics = getAnalytics(app);
    window.analytics = analytics;
    window.logEvent = logEvent;
}

// HTMX 4 puts DELETE parameters in the URL. Send the CSRF token as a header
// for every state-changing HTMX request so it never appears in the query string.
document.addEventListener("htmx:config:request", (event) => {
    const request = event.detail.ctx.request;

    if (["POST", "PUT", "PATCH", "DELETE"].includes(request.method)) {
        const token = document.querySelector(
            'meta[name="csrf-token"]',
        )?.content;

        if (token) {
            request.headers["X-CSRF-TOKEN"] = token;
        }
    }
});

function initializeContent(root) {
    decodePromptTooltips(root);
    void setupLogo(root, assetUrl);
    setupPasteImage(root);
    setupCopyCodeButton(root);
    void setupStork(root, assetUrl);
}

// 备忘：为什么这里使用 htmx.onLoad
// https://github.com/bigskysoftware/htmx/discussions/3126#discussioncomment-11820869
//
// 首次加载时，HTMX 会以整个 body 调用一次 callback；但 hx-boost 等价于
// hx-target="body" + hx-swap="innerHTML"，替换 body 内容后，HTMX 仍会逐个处理
// body 的顶级子元素。因此 body 有多个顶级元素时，callback 也会执行多次。
//
// 项目通过 #htmx-onload-root 保持 body 只有一个顶级元素，确保整页替换只调用
// 一次 callback。initializeContent 仍只查找本次传入的 root 及其后代，以便正确
// 处理局部替换。HTMX 4 的 history 恢复会重新请求并处理 HTML，也会自然走这个
// 入口，无须再监听单独的 history 事件。
htmx.onLoad(initializeContent);

function setupCopyCodeButton(root) {
    findElements(root, "pre.b").forEach(copyCodeButton);
}

function setupPasteImage(root) {
    findElements(root, "textarea").forEach(pasteImage);
}
