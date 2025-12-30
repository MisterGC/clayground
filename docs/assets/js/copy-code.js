// Add copy buttons to all code blocks
document.addEventListener('DOMContentLoaded', function() {
  const codeBlocks = document.querySelectorAll('div.highlighter-rouge, pre.highlight');

  codeBlocks.forEach(function(block) {
    // Skip if already has a button
    if (block.querySelector('.copy-button')) return;

    // Create button
    const button = document.createElement('button');
    button.className = 'copy-button';
    button.textContent = 'Copy';
    button.setAttribute('aria-label', 'Copy code to clipboard');

    // Position container
    block.style.position = 'relative';

    button.addEventListener('click', function() {
      const code = block.querySelector('code');
      const text = code ? code.textContent : block.textContent;

      navigator.clipboard.writeText(text).then(function() {
        button.textContent = 'Copied!';
        button.classList.add('copied');
        setTimeout(function() {
          button.textContent = 'Copy';
          button.classList.remove('copied');
        }, 2000);
      }).catch(function() {
        button.textContent = 'Failed';
        setTimeout(function() {
          button.textContent = 'Copy';
        }, 2000);
      });
    });

    block.appendChild(button);
  });
});
