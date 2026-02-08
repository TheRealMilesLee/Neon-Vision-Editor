# Language Fixtures

Manual verification checklist:

1. Open each file in the app.
2. Confirm the language picker switches to the expected language:
   - `.env.sample` -> Dotenv
   - `schema.proto` -> Proto
   - `schema.graphql` -> GraphQL
   - `index.rst` -> reStructuredText
   - `nginx.conf` -> Nginx
3. Confirm syntax highlighting shows keywords, strings, and comments where applicable.
4. Paste each file's contents into a new tab and confirm the picker updates.
