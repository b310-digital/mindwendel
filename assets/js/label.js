const setIdeaLabelBackgroundColor = (el) => {
  const color = el.getAttribute("data-color");
  el.style.backgroundColor = color;
}

export { setIdeaLabelBackgroundColor }