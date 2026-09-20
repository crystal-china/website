let hideTimer;

function showError(message) {
    const alert = document.getElementById("htmx-error-alert");

    if (alert == null) {
        return;
    }

    alert.textContent = message;
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
            return "提交内容有误，请检查后重试。";
        case 401:
            return "登录状态已失效，请重新登录。";
        case 403:
            return "你没有执行此操作的权限。";
        case 404:
            return "请求的内容不存在或已被删除。";
        case 409:
            return "内容已发生变化，请刷新后重试。";
        default:
            return "服务器暂时无法处理请求，请稍后重试。";
    }
}

export default function setupHtmxErrorAlert() {
    document.addEventListener("htmx:response:error", (event) => {
        showError(messageForStatus(event.detail.ctx.response.status));
    });

    document.addEventListener("htmx:error", () => {
        showError("网络请求失败，请检查网络后重试。");
    });
}
