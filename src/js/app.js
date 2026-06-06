/* eslint no-console:0 */

import { initializeApp } from "firebase/app";
import { getAnalytics, logEvent } from "firebase/analytics";
import htmx from "htmx.org";
import _hyperscript from "hyperscript.org";

import copyCodeButton from "./copyCodeButton.js";
import pasteImage from "./pasteImage.js";
import stork from "./stork.js";
import Viewer3D from "./viewer3d.js";

_hyperscript.browserInit();

const frontendConfig = JSON.parse(
    document.getElementById("app-config")?.textContent ?? "{}",
);
const assetHost = frontendConfig.assetHost ?? "";
const firebaseConfig = frontendConfig.firebaseConfig ?? {};

let assetManifestPromise;

function loadAssetManifest() {
    if (assetManifestPromise == null) {
        assetManifestPromise = fetch("/bun-manifest.json", {
            cache: "no-store",
        })
            .then((response) => {
                if (!response.ok) {
                    throw new Error(
                        `Failed to load bun-manifest.json: ${response.status}`,
                    );
                }

                return response.json();
            })
            .catch((error) => {
                console.warn(error);
                return {};
            });
    }

    return assetManifestPromise;
}

async function assetUrl(logicalPath, fallback = `/assets/${logicalPath}`) {
    const manifest = await loadAssetManifest();
    return `${assetHost}${manifest[logicalPath] ?? fallback}`;
}

// import * as AsciinemaPlayer from 'asciinema-player';
// AsciinemaPlayer.create('/demo.cast', document.getElementById('demo'));

function init(eventElt) {
    // htmx.logger = function (elt, event, data) {
    //     if (console) {
    //         console.log(event, elt, data);
    //     }
    // };

    if (firebaseConfig.apiKey != null) {
        const app = initializeApp(firebaseConfig);
        const analytics = getAnalytics(app);
        window.analytics = analytics;
        window.logEvent = logEvent;
    }

    window.scrollToElementById = scrollToElementById;

    // Delete 请求仍旧使用 form-encoded body 来传递参数。
    // htmx 2.0, 对于 DELETE 请求，将使用 params （根据 spec 规定）
    // 这里设定，仅仅 get 请求使用 params
    htmx.config.methodsThatUseUrlParams = ["get"];
    // 2.0 不允许使用 htmx 执行 cross-domain requests.
    // 取消注释来允许它正常发送请求。
    // htmx.config.selfRequestsOnly = false;

    // 确保下面的函数，只在 body 重新改变时才触发
    if (eventElt.nodeName == "BODY") {
        void initStork();
    }

    // 让 data-tooltip 属性可以显示中文
    document.querySelectorAll("[data-tooltip]").forEach((el) => {
        // 解码 data-tooltip 的值
        const decodedTooltip = decodeURIComponent(
            el.getAttribute("data-tooltip"),
        );

        // 设置一个新的属性 data-tooltip-decoded，用于存储解码后的值
        el.setAttribute("data-tooltip-decoded", decodedTooltip);
    });

    // console.log(eventElt.getAttribute("class"));
    // 确保激活的这个 div 不包含 htmx-settling
    // 目前猜测所有使用 htmx-trigger="load" 激活的 swap，js callback 也会被执行。
    // 此时重复执行 js 的 callback 会引起问题，例如，render Logo 动画两次。
    // 为了避免重复执行，做一个判断。（不确定是不是总是有效）
    if (!eventElt.className.includes("htmx-settling")) {
        void setupLogo(eventElt);
        setupPasteImage(eventElt);
        setupCopyCodeButton(eventElt);
        setupStork(eventElt);
    }
}

// 备忘，为什么这里不直接使用 htmx.onLoad 呢？
// https://github.com/bigskysoftware/htmx/discussions/3126#discussioncomment-11820869

//  htmx will fire htmx:load on every top-level child of the swapped content.
// When you use hx-boost, it's an equivalent to hx-target="body" hx-swap="innerHTML",
// which will replace the content of the body, then fire htmx:load on its direct descendants,
// so here the header, div and dialog from your screenshot indeed.

// 然后，为什么现在又用回了 onLoad, 因为现在经过重构，body 下面只有一个顶级的 div,
// 之前事件绑定重复激发的情况不存在了，而且，onLoad 可以很好的处理 history 相关的问题。
// 不必再单独为 htmx:historyRestore" 事件绑定一遍了。

htmx.onLoad(init);

// https://htmx.org/docs/#undoing-dom-mutations-by-3rd-party-libraries
// 当全局开启 hx-boost 之后，有义务在 htmx:beforeHistorySave 的 callback 中，
// 将一些 js 库的针对 DOM 的修改回滚到初始状态，以使得 htmx history 在载入时，
// 运行 js 来重新初始化。
// 因为上面有 htmx-settling 的判断，这个其实不是必须的，但这是 htmx 推荐的方式。
document.body.addEventListener("htmx:beforeHistorySave", function (event) {
    document.getElementById("logo-canvas")?.setAttribute("running", "false");
});

async function setupLogo(eventElt) {
    const canvas = document.getElementById("logo-canvas");

    if (canvas != null && canvas.getAttribute("running") === "false") {
        // setIPhoneDataAttribute
        let platform = navigator?.userAgent || navigator?.platform || "unknown";

        if (/iPhone/.test(platform)) {
            document.documentElement.dataset.uaIphone = true;
        }

        // startLogoAnimation
        var model = new Viewer3D(canvas);
        model.shader("flat", 255, 255, 255);
        model.insertModel(await assetUrl("models/icosahedron.xml"));
        model.contrast(0.9);
        canvas.setAttribute("running", "true");
    }
}

function setupStork(eventElt) {
    let storkContainer = eventElt.querySelector("input[data-stork='docs']");
    if (storkContainer != null) {
        stork.attach("docs");
    }
}

async function initStork() {
    stork.initialize(await assetUrl("docs/stork.wasm"));
    stork.downloadIndex("docs", await assetUrl("docs/index.st"));
}

function setupCopyCodeButton(eventElt) {
    eventElt.querySelectorAll("pre.b").forEach(copyCodeButton);

    // If it's possible that a block is at the top level of the response,
    // you'll want to check the root elt itself
    if (eventElt instanceof Element) {
        if (eventElt.matches("pre.b")) {
            pasteImage(eventElt);
        }
    }
}

function setupPasteImage(eventElt) {
    eventElt.querySelectorAll("textarea").forEach(pasteImage);

    if (eventElt instanceof Element) {
        if (eventElt.matches("textarea")) {
            pasteImage(eventElt);
        }
    }
}

function scrollToElementById(someId) {
    const element = document.getElementById(someId);

    if (element) {
        element.scrollIntoView({
            behavior: "smooth", // 平滑滚动
            block: "center", // 元素在视窗中的对齐位置（"center" 表示居中）
        });
    }
}
