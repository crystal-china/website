import t from "./i18n.js";

let hideTimer;

function showError(message, networkError = false) {
    const alert = document.getElementById("htmx-error-alert");

    if (alert == null) {
        return;
    }

    alert.querySelector("[data-htmx-error-icon]").hidden = !networkError;
    alert.querySelector("[data-htmx-error-message]").textContent = message;
    alert.hidden = false;

    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => {
        if (alert.isConnected) {
            alert.hidden = true;
        }
    }, 6000);
}

function messageForStatus(status) {
    switch (status) {
        case 400:
        case 422:
            return t("invalid_request");
        case 401:
            return t("sign_in_required");
        case 403:
            return t("forbidden");
        case 404:
            return t("not_found");
        case 409:
            return t("conflict");
        default:
            return t("server_error");
    }
}

export default function setupHtmxErrorAlert(htmx) {
    document.addEventListener("htmx:before:request", (event) => {
        const { ctx } = event.detail;
        const timeout = ctx.request.timeout != null
            ? htmx.parseInterval(ctx.request.timeout)
            : htmx.config.defaultTimeout;

        // HTMX 4 的主动取消和超时都是 AbortError，只有计时器触发才标记为超时。
        // 沿用 requestTimeout，让 HTMX 在请求结束时清理计时器。
        clearTimeout(ctx.requestTimeout);
        if (timeout) {
            ctx.requestTimeout = setTimeout(() => {
                ctx.requestTimedOut = true;
                ctx.request.abort();
            }, timeout);
        }
    });

    document.addEventListener("htmx:response:error", (event) => {
        showError(messageForStatus(event.detail.ctx.response.status));
    });

    document.addEventListener("htmx:error", (event) => {
        const { ctx, error } = event.detail;

        if (error?.name === "AbortError" && !ctx?.requestTimedOut) {
            return;
        }

        if (!navigator.onLine) {
            showError(t("offline"), true);
        } else if (error?.name === "AbortError") {
            showError(t("timeout"));
        } else if (ctx != null && ctx.response == null) {
            showError(t("connection_failed"), true);
        } else {
            showError(t("interaction_failed"));
        }
    });
}
