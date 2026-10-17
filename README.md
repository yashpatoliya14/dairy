# Dairy Desk

A Flutter customer-management UI for dairy operators. It includes email/password
login and signup, a searchable customer list, and a create-customer form.

## Backend connection

The app calls these JSON endpoints:

- `POST /auth/login` and `POST /auth/signup`
- `GET /customers` and `POST /customers`

The default API URL is `https://dairy-backend-eemp.onrender.com`. Override it for another environment:

```shell
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api
```

For a physical Android device, use the development machine's LAN IP
(`10.209.254.112`), and make sure the backend port is reachable through the
firewall.
Use an HTTPS URL for production builds.

Successful authentication stores the returned `token` (or `accessToken`) in
`SharedPreferences` and sends it as a Bearer token on customer requests.
