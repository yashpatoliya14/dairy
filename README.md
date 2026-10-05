# Dairy Desk

A Flutter customer-management UI for dairy operators. It includes email/password
login and signup, a searchable customer list, and a create-customer form.

## Backend connection

The app calls these JSON endpoints:

- `POST /auth/login` and `POST /auth/signup`
- `GET /customers` and `POST /customers`

The default API URL is `http://10.0.2.2:3000/api` (Android emulator access to a
local backend). Override it for another environment:

```shell
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api
```

Successful authentication stores the returned `token` (or `accessToken`) in
`SharedPreferences` and sends it as a Bearer token on customer requests.
