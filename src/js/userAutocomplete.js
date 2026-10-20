const initialized = new WeakSet();

export default function setupUserAutocomplete(input, {
    currentToken = () => ({ start: 0, end: input.value.length, prefix: input.value.trim() }),
    replace = (user) => {
        input.value = user.login_name;
        input.dispatchEvent(new Event("change", { bubbles: true }));
    },
    selectFirst = false,
    selectOnTab = false,
} = {}) {
    if (input.disabled || initialized.has(input)) return;

    const list = input.parentElement.querySelector(".user-autocomplete-options");
    if (!list) return;
    initialized.add(input);

    let timer;
    let request;
    let users = [];
    let selected = -1;
    let token;

    function isCurrent(expected) {
        const current = currentToken();
        return current && current.start === expected.start && current.end === expected.end && current.prefix === expected.prefix;
    }

    function close() {
        clearTimeout(timer);
        request?.abort();
        users = [];
        selected = -1;
        list.replaceChildren();
        list.hidden = true;
    }

    function choose(index) {
        if (!isCurrent(token)) {
            close();
            return;
        }

        replace(users[index], token);
        close();
    }

    function highlight() {
        [...list.children].forEach((button, index) => {
            button.classList.toggle("bg-sky-50", index === selected);
        });
        const active = list.children[selected];
        if (active.offsetTop < list.scrollTop) {
            list.scrollTop = active.offsetTop;
        } else if (active.offsetTop + active.offsetHeight > list.scrollTop + list.clientHeight) {
            list.scrollTop = active.offsetTop + active.offsetHeight - list.clientHeight;
        }
    }

    input.addEventListener("input", (event) => {
        close();
        token = currentToken();

        if (event.isComposing || !token || token.prefix.length < 2) return;

        const expected = token;
        timer = setTimeout(async () => {
            if (!input.isConnected || document.activeElement !== input || !isCurrent(expected)) return;

            const controller = new AbortController();
            request = controller;
            const url = new URL(input.dataset.usersAutocompleteUrl, location.origin);
            url.searchParams.set("q", expected.prefix);

            try {
                const response = await fetch(url, {
                    signal: controller.signal,
                    headers: { Accept: "application/json", "HX-Request-Type": "partial" },
                });
                if (!response.ok) return;

                const suggestions = await response.json();
                // 请求期间可能换页或移动光标，过时的结果不能挂到新位置。
                if (controller.signal.aborted || !input.isConnected || document.activeElement !== input || !isCurrent(expected)) return;

                users = suggestions;
                selected = selectFirst ? 0 : -1;
                list.replaceChildren(...users.map((user, index) => {
                    const button = document.createElement("button");
                    button.type = "button";
                    button.tabIndex = -1;
                    button.className = "block w-full cursor-pointer px-4 py-2 text-left text-sm text-sky-800 hover:bg-sky-50";
                    button.textContent = `${user.nickname} @${user.login_name}`;
                    // 保持输入框焦点，避免 blur 先关闭列表、吞掉选中操作。
                    button.addEventListener("pointerdown", (event) => event.preventDefault());
                    button.addEventListener("click", () => choose(index));
                    return button;
                }));
                list.hidden = users.length === 0;
                if (users.length && selected >= 0) highlight();
            } catch {
                // 自动补全失败不阻止正常输入，也不将网络错误写进正文。
                // 仅关闭当前请求的列表，避免旧请求清空较新的候选结果。
                if (request === controller) close();
            }
        }, 250);
    });

    input.addEventListener("keydown", (event) => {
        if (list.hidden || event.isComposing) return;

        if (event.key === "Escape") {
            event.preventDefault();
            // Escape 先关闭补全，不触发外层编辑对话框的放弃修改确认。
            event.stopPropagation();
            close();
        } else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
            event.preventDefault();
            event.stopPropagation();
            const backwards = event.key === "ArrowUp";
            selected = selected < 0
                ? (backwards ? users.length - 1 : 0)
                : (selected + (backwards ? -1 : 1) + users.length) % users.length;
            highlight();
        } else if ((event.key === "Enter" || (selectOnTab && event.key === "Tab" && !event.shiftKey)) && selected >= 0) {
            event.preventDefault();
            event.stopPropagation();
            choose(selected);
        } else if (event.key === "Enter") {
            close();
        }
    });
    input.addEventListener("blur", close);
    input.addEventListener("click", close);
}
