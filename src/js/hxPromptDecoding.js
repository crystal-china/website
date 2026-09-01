// HTMX 4 将 hx-prompt 移出核心；先加载扩展以恢复属性及 HX-Prompt 请求头。
import "htmx.org/dist/ext/hx-prompt.js";
import findElements from "./findElements.js";

function decodePromptTooltips(root) {
    // 让 data-tooltip 属性可以显示中文
    findElements(root, "[data-tooltip]").forEach((el) => {
        // 解码 data-tooltip 的值
        const decodedTooltip = decodeURIComponent(
            el.getAttribute("data-tooltip"),
        );

        // 设置一个新的属性 data-tooltip-decoded，用于存储解码后的值
        el.setAttribute("data-tooltip-decoded", decodedTooltip);
    });
}

export default decodePromptTooltips;
