# Good Night API Collection

## 1. Follow

### Follow User

- **Method**: `POST`
- **URL**: `localhost:3000/users/3/following`
- **Headers**:
  - `X-User-Id: <user-id>`

**Responses**:

- **Success (201 Created)**:
```json
{
  "message": "Followed user successfully"
}
```

- **Failure (400 Bad Request)**:
```json
{
  "error": "Already following this user"
}
```

### Unfollow User

- **Method**: `DELETE`
- **URL**: `localhost:3000/users/3/following`
- **Headers**:
  - `X-User-Id: <user-id>`

**Responses**:

- **Success (200 OK)**:
```json
{
  "message": "Unfollowed user successfully"
}
```

- **Failure (400 Bad Request)**:
```json
{
  "error": "Not following this user"
}
```

---

## 2. Sleep Record

### List Sleep Records

- **Method**: `GET`
- **URL**: `localhost:3000/sleep_records`
- **Headers**:
  - `X-User-Id: <user-id>`

**Note**: Query parameters like `limit` and `cursor` are available but disabled.

**Success Response (200 OK)**:
```json
{
  "data": [
    {
      "id": 37,
      "user_id": 2,
      "clock_in": "2025-05-26T19:51:04.020Z",
      "clock_out": "2025-05-26T19:51:06.700Z",
      "sleep_time": 2.6802
    }
  ],
  "next_cursor": "Mi42MTU5MjU="
}
```

### Clock-In Sleep Record

- **Method**: `POST`
- **URL**: `localhost:3000/sleep_records/clock_in`
- **Headers**:
  - `X-User-Id: <user-id>`

**Responses**:

- **Success (201 Created)**:
```json
{
  "id": 41,
  "user_id": 2,
  "clock_in": "2025-05-26T19:51:04.020Z",
  "clock_out": null,
  "sleep_time": null
}
```

- **Failure (400 Bad Request)**:
```json
{
  "error": "You already have an active sleep session"
}
```

### Clock-Out Sleep Record

- **Method**: `PUT`
- **URL**: `localhost:3000/sleep_records/clock_out`
- **Headers**:
  - `X-User-Id: <user-id>`

**Responses**:

- **Success (200 OK)**:
```json
{
  "id": 37,
  "user_id": 2,
  "clock_in": "2025-05-26T19:51:04.020Z",
  "clock_out": "2025-05-26T19:51:06.700Z",
  "sleep_time": 2.6802
}
```

- **Failure (400 Bad Request)**:
```json
{
  "error": "No active sleep session found"
}
```
