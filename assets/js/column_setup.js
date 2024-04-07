// configure link list - on iOS, the navigation bar is dynamic. when it's expanded,
// the link list would be below the fold or very close to the edge.
// to handle this, we adjust the size of the column to the inner height of the window
const leftColumn = document.getElementById("left-column");

function setLeftColumnHeight() {
  if (leftColumn) {
    leftColumn.style.setProperty('height', `${window.innerHeight}px`, 'important')
  }
}
// change the left column size whenever the window is resized
window.addEventListener("resize", setLeftColumnHeight);

// call initially:
setLeftColumnHeight();