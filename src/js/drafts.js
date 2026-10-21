const initialized = new WeakSet();
const keyPrefix = "draft:";

export function setupDraft(container) {
    if (initialized.has(container)) return;
    initialized.add(container);

    const key = keyPrefix + container.dataset.draftKey;
    const fields = [...container.querySelectorAll("[data-draft-field]")];

    try {
        const draft = JSON.parse(window.localStorage.getItem(key));
        for (const field of fields) {
            if (typeof draft?.[field.name] === "string") {
                field.value = draft[field.name];
            }
        }
    } catch {
        // 存储被禁用或旧草稿损坏时，不影响正常编辑和提交。
    }

    container.addEventListener("input", save);
    container.addEventListener("change", save);

    function save() {
        try {
            // 连空值一起保存，否则主动清空字段后可能恢复出旧内容。
            const values = Object.fromEntries(fields.map((field) => [field.name, field.value]));
            window.localStorage.setItem(key, JSON.stringify(values));
        } catch {
            // 浏览器禁用存储或空间不足时，仍然可以编辑和提交。
        }
    }
}

export function clearSavedDraft(event) {
    const ctx = event.detail.ctx;
    if (!ctx.response.raw.ok || ctx.response.raw.headers.get("X-Draft-Saved") !== "true") return;

    const container = ctx.sourceElement.closest("[data-draft-key]");
    if (!container) return;

    try {
        window.localStorage.removeItem(keyPrefix + container.dataset.draftKey);
    } catch {
        // 草稿存储失败不应阻止服务器已成功的提交。
    }
}
