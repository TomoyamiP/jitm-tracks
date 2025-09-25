// app/javascript/application.js
import "@hotwired/turbo-rails"
import "controllers"

function wireAboutModal() {
  const openBtn = document.querySelector("#about-link");
  const modal   = document.querySelector("#about-modal");
  if (!openBtn || !modal) return;

  const closeEls = modal.querySelectorAll("[data-close-modal]");

  const openModal = (e) => {
    if (e) e.preventDefault();
    modal.classList.remove("hidden");
    modal.setAttribute("aria-hidden", "false");
    // optional: prevent background scroll while modal open
    document.body.style.overflow = "hidden";
    const closeBtn = modal.querySelector(".modal-close");
    if (closeBtn) closeBtn.focus();
  };

  const closeModal = () => {
    modal.classList.add("hidden");
    modal.setAttribute("aria-hidden", "true");
    document.body.style.overflow = ""; // restore scroll
    if (document.body.contains(openBtn)) openBtn.focus();
  };

  // Avoid double-binding on Turbo visits
  openBtn.removeEventListener("click", openModal);
  openBtn.addEventListener("click", openModal);

  closeEls.forEach((el) => {
    el.removeEventListener("click", closeModal);
    el.addEventListener("click", closeModal);
  });

  // Close on Escape
  const escHandler = (e) => {
    if (e.key === "Escape" && !modal.classList.contains("hidden")) closeModal();
  };
  document.removeEventListener("keydown", escHandler);
  document.addEventListener("keydown", escHandler);
}

// Run on initial load AND on every Turbo visit
document.addEventListener("turbo:load", wireAboutModal);
document.addEventListener("DOMContentLoaded", wireAboutModal);
