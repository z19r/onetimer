document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", () => {
    const code = button.closest("[data-code-block]").querySelector("code").textContent;
    navigator.clipboard.writeText(code).then(() => {
      const original = button.textContent;
      button.textContent = "Copied";
      setTimeout(() => { button.textContent = original; }, 1400);
    });
  });
});
