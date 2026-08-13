# Browser

The browser lets a person find cards through their language or source book.

`browser.dart` is its public vocabulary. `browser_page.dart` branches into
`language/` or `book_page.dart`, then through reusable `card_list/` views and
`card_details_page.dart`. `data/kgql/` fetches and translates server data;
`data/models/` contains the application-ready concepts consumed everywhere
else.
