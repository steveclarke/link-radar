import './style.css';

console.log('Link Radar popup loaded');

// Get current tab URL
browser.tabs.query({ active: true, currentWindow: true }).then((tabs) => {
  const currentTab = tabs[0];
  console.log('Current tab:', currentTab.url);
});

