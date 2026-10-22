# Dairy Desk

A Flutter customer-management UI for dairy operators. It includes email/password
login and signup, a searchable customer list, and a create-customer form.

## Backend connection

The app calls these JSON endpoints:

- `POST /auth/login` and `POST /auth/signup`
- `GET /customers` and `POST /customers`
- `POST /whatsapp/send-bill`

The default API URL is `https://dairy-backend-eemp.onrender.com`. Override it for another environment:

```shell
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api
```

For a physical Android device, use the development machine's LAN IP
(`10.209.254.112`), and make sure the backend port is reachable through the
firewall.
Use an HTTPS URL for production builds.

Bill notifications use the backend's approved WhatsApp template by default,
which allows sending outside WhatsApp's 24-hour customer-service window. The
backend must have a valid WhatsApp Cloud API token and an approved
`WHATSAPP_MILK_BILL_TEMPLATE_NAME` configured (default template:
`dairy_milk_bill_update`).

Successful authentication stores the returned `token` (or `accessToken`) in
`SharedPreferences` and sends it as a Bearer token on customer requests.
