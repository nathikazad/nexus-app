const article = new Readability(document.cloneNode(true)).parse();
if (!article) return null;
const body = document.createElement('div');
body.innerHTML = article.content;
body.querySelectorAll('script, style, nav, form, button').forEach(e => e.remove());
body.querySelectorAll('br').forEach(e => e.replaceWith('\n'));
body.querySelectorAll('p, h1, h2, h3, h4, li, blockquote, pre, tr')
  .forEach(e => e.append('\n\n'));
return JSON.stringify({title: article.title, text: body.textContent});
