import setupUserAutocomplete from "./userAutocomplete.js";

export default function setupMentions(textarea) {
    function currentToken() {
        if (textarea.selectionStart !== textarea.selectionEnd) {
            return null;
        }
        const end = textarea.selectionStart;
        const match = textarea.value.slice(0, end).match(/(?:^|[^A-Za-z0-9@])@([^\s<>`,，。!！?？:：;；@]*)$/u);

        if (!match) return null;

        const start = end - match[1].length - 1;
        let backslashes = 0;

        for (let index = start - 1; index >= 0 && textarea.value[index] === "\\"; index--) {
            backslashes++;
        }

        if (backslashes % 2 === 1) return null;

        return { start, end, prefix: match[1] };
    }

    setupUserAutocomplete(textarea, {
        currentToken,
        replace(user, token) {
            textarea.setRangeText(`@${user.login_name} `, token.start, token.end, "end");
            textarea.dispatchEvent(new Event("input", { bubbles: true }));
        },
        selectFirst: true,
        selectOnTab: true,
    });
}
