const initialized = new WeakSet();
let nextListId = 0;

export default function setupMentions(textarea) {
    if (textarea.disabled || initialized.has(textarea)) {
        return;
    }
    initialized.add(textarea);

    const list = document.createElement("div");
    list.id = `mention-options-${++nextListId}`;
    list.setAttribute("role", "listbox");
    list.setAttribute("aria-label", "提及用户");
    list.className = "absolute inset-x-4 bottom-4 z-20 max-h-56 overflow-y-auto rounded-xl border border-gray-200 bg-white py-1 shadow-lg";
    list.hidden = true;
    textarea.after(list);
    textarea.setAttribute("aria-controls", list.id);
    textarea.setAttribute("aria-autocomplete", "list");

    let timer;
    let request;
    let names = [];
    let selected = 0;
    let token;

    function currentToken() {
        if (textarea.selectionStart !== textarea.selectionEnd) {
            return null;
        }
        const end = textarea.selectionStart;
        const match = textarea.value.slice(0, end).match(/(?:^|[^A-Za-z0-9_@])@([^\s<>`,，。!！?？:：;；@]*)$/u);
        return match ? { start: end - match[1].length - 1, end, prefix: match[1] } : null;
    }

    function close() {
        clearTimeout(timer);
        request?.abort();
        list.hidden = true;
        names = [];
        textarea.removeAttribute("aria-activedescendant");
    }

    function highlight() {
        [...list.children].forEach((button, index) => {
            const active = index === selected;
            button.classList.toggle("bg-sky-50", active);
            button.setAttribute("aria-selected", String(active));
        });
        const active = list.children[selected];
        textarea.setAttribute("aria-activedescendant", active.id);
        if (active.offsetTop < list.scrollTop) {
            list.scrollTop = active.offsetTop;
        } else if (active.offsetTop + active.offsetHeight > list.scrollTop + list.clientHeight) {
            list.scrollTop = active.offsetTop + active.offsetHeight - list.clientHeight;
        }
    }

    function choose(index) {
        const current = currentToken();
        if (!current || current.start !== token.start || current.prefix !== token.prefix) {
            close();
            return;
        }
        textarea.setRangeText(`@${names[index]} `, current.start, current.end, "end");
        close();
        textarea.focus();
        textarea.dispatchEvent(new Event("input", { bubbles: true }));
    }

    textarea.addEventListener("input", (event) => {
        close();
        token = currentToken();
        if (event.isComposing || !token?.prefix) {
            return;
        }

        const expected = token;
        timer = setTimeout(async () => {
            const controller = new AbortController();
            request = controller;
            const url = new URL(textarea.dataset.mentionsUrl, location.origin);
            url.searchParams.set("q", expected.prefix);

            try {
                const response = await fetch(url, { signal: controller.signal, headers: { Accept: "application/json", "HX-Request-Type": "partial" } });
                if (!response.ok) {
                    return;
                }
                const suggestions = await response.json();
                const current = currentToken();
                // 请求期间可能换页或移动光标，过时的结果不能挂到新位置。
                if (controller.signal.aborted || !textarea.isConnected || document.activeElement !== textarea || current?.start !== expected.start || current?.prefix !== expected.prefix) {
                    return;
                }

                names = suggestions;
                selected = 0;
                list.replaceChildren();
                names.forEach((name, index) => {
                    const button = document.createElement("button");
                    button.type = "button";
                    button.id = `${list.id}-${index}`;
                    button.setAttribute("role", "option");
                    button.tabIndex = -1;
                    button.className = "block w-full cursor-pointer px-4 py-2 text-left text-sm text-sky-800 hover:bg-sky-50";
                    button.textContent = `@${name}`;
                    button.addEventListener("pointerdown", (event) => event.preventDefault());
                    button.addEventListener("click", () => choose(index));
                    list.append(button);
                });
                list.hidden = names.length === 0;
                if (names.length) {
                    highlight();
                }
            } catch (error) {
                // 自动补全失败不阻止正常输入，也不将网络错误写进正文。
                if (error.name !== "AbortError" && request === controller) {
                    close();
                }
            }
        }, 250);
    });

    textarea.addEventListener("keydown", (event) => {
        if (list.hidden || event.isComposing) {
            return;
        }
        if (event.key === "Tab" && event.shiftKey) {
            close();
            return;
        }
        if (["ArrowDown", "ArrowUp", "Enter", "Tab", "Escape"].includes(event.key)) {
            event.preventDefault();
            // Escape 先关闭补全，不触发外层编辑对话框的放弃修改确认。
            event.stopPropagation();
            if (event.key === "Escape") {
                close();
            } else if (event.key === "Enter" || event.key === "Tab") {
                choose(selected);
            } else {
                selected = (selected + (event.key === "ArrowDown" ? 1 : -1) + names.length) % names.length;
                highlight();
            }
        }
    });
    textarea.addEventListener("blur", close);
    textarea.addEventListener("click", close);
}
