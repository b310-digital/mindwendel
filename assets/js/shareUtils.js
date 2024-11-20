export const initShareButtonClickHandler = (button) => {
  const shareData = {
    title: button.getAttribute(`data-native-sharing-button-share-data-title`) || 'Mindwendel Brainstorming',
    text: button.getAttribute(`data-native-sharing-button-share-data-text`) || 'Join my brainstorming',
    url: document.getElementById("data-native-sharing-button-share-data-url") || document.getElementById("brainstorming-link-input-readonly").value
  }

  const clickHandler = (_event) => {
    navigator.share(shareData)
      .then() // Do nothing
      .catch(err => { console.log(`Error: ${err}`) })
  }

  if (navigator.share) {
    button.addEventListener('click', clickHandler);
    return clickHandler;
  }
}