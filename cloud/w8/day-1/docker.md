# **1. sample**

    FROM node:20

    WORKDIR /app

    COPY package*.json ./

    RUN npm ci

    COPY . .

    EXPOSE 3000

    CMD ["npm", "start"]

***

<hr>

***

    FROM golang:1.24

    WORKDIR /app

    COPY . .

    RUN go build -o main .

    CMD ["./main"]

***

<hr>

***

    FROM golang:1.24 AS builder

    WORKDIR /app

    COPY . .

    RUN go build -o main .

    FROM scratch

    COPY --from=builder /app/main .

    CMD ["./main"]

***

<hr>

***

    FROM rust:1.88

    WORKDIR /app

    COPY . .

    RUN cargo build --release

    CMD ["./target/release/myapp"]

***

<hr>

***

    FROM rust:1.88 AS builder

    WORKDIR /app

    COPY . .

    RUN cargo build --release

    FROM debian:bookworm-slim

    COPY --from=builder /app/target/release/myapp /myapp

    CMD ["/myapp"]

***

<hr>

***

    FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

    WORKDIR /src

    COPY . .

    RUN dotnet publish -c Release -o /publish

    FROM mcr.microsoft.com/dotnet/aspnet:9.0

    WORKDIR /app

    COPY --from=build /publish .

    ENTRYPOINT ["dotnet","MyApp.dll"]

***

<hr>

***

    FROM mcr.microsoft.com/dotnet/sdk:8.0 AS buildSample
    WORKDIR /src

    COPY . .
    RUN dotnet restore
    RUN dotnet publish -c Release -o /app/publish

    FROM mcr.microsoft.com/dotnet/aspnet:8.0
    WORKDIR /app

    COPY --from=buildSample /app/publish .
    ENTRYPOINT ["dotnet","MyApp.dll"]

# **2. explanation**

## **2.1 Các Keywords cơ bản**

| Keyword | Ý nghĩa | Ví dụ |
|---------|---------|--------|
| **FROM** | Base image (OS + runtime) | `FROM node:20` = lấy Node.js 20 làm nền. Docker sẽ download nó nếu chưa có |
| **WORKDIR** | Thư mục làm việc trong container | `WORKDIR /app` = tương tự `cd /app` trên terminal. Mọi lệnh sau sẽ chạy ở đây |
| **COPY** | Copy file từ host vào container | `COPY . .` = copy toàn bộ source code hiện tại vào container. Có thể dùng `COPY package.json ./` để copy file cụ thể |
| **RUN** | Chạy lệnh trong container (khi build) | `RUN npm install` = cài đặt packages. Mỗi RUN tạo 1 layer mới |
| **EXPOSE** | Khai báo port sẽ sử dụng | `EXPOSE 3000` = app sẽ listen port 3000 bên trong container (chỉ là khai báo, không thực sự map port) |
| **CMD** | Lệnh mặc định khi container start | `CMD ["npm", "start"]` = chạy `npm start` khi container khỏi động |
| **ENTRYPOINT** | Lệnh entry point (thay thế CMD) | `ENTRYPOINT ["dotnet", "MyApp.dll"]` = luôn chạy lệnh này, CMD không thể override (trong .NET thường dùng ENTRYPOINT) |

### **.dockerignore**
- Hoạt động như `.gitignore`
- Chỉ định tệp/thư mục **không được đưa vào container** khi `COPY . .`
- Ví dụ: `node_modules/`, `.git/`, `.env`

---

## **2.2 Port Mapping - Chi tiết**

### **EXPOSE vs Port Mapping**
```dockerfile
EXPOSE 3000      # ← Dockerfile: Chỉ khai báo, không map port
```

```bash
docker run -p 8080:3000 myapp    # ← Docker command: Thực hiện map port
```

**Giải thích:**
- **Port 3000** (container port): App bên trong container listen ở port này
- **Port 8080** (host port): Cổng của máy host (PC bạn) dùng để access app
- Traffic từ `localhost:8080` → **map** → `container:3000`

**Tại sao cần map port?**
- Container là **isolated environment** - port bên trong nó không accessible từ ngoài
- Kiểu như container là phòng riêng với cửa khóa, port mapping là tạo lối dẫn từ ngoài vào

**Ví dụ thực tế:**
```bash
docker run -p 8080:3000 myapp      # Truy cập via http://localhost:8080
docker run -p 9000:3000 myapp      # Container khác, truy cập via http://localhost:9000
```
Cùng 1 image, 2 container khác nhau với 2 port khác nhau - không xung đột vì cách ly.

---

## **2.3 Multi-Stage Build - Tối ưu Image Size**

### **Vấn đề: Single-stage build (lãng phí)**
```dockerfile
FROM golang:1.24
WORKDIR /app
COPY . .
RUN go build -o main .
CMD ["./main"]
```
- Image cuối có: **cả Golang SDK** (300MB+) + binary nhỏ (10MB)
- Image size: ~310MB (lãng phí vì không cần SDK khi chạy app)

### **Giải pháp: Multi-stage build (hiệu quả)**
```dockerfile
# Stage 1: Build
FROM golang:1.24 AS builder
WORKDIR /app
COPY . .
RUN go build -o main .

# Stage 2: Runtime (copy từ stage 1)
FROM scratch
COPY --from=builder /app/main .
CMD ["./main"]
```
- **Stage 1** (`AS builder`): Compile binary (có SDK)
- **Stage 2** (final): Chỉ copy binary từ stage 1, không cần SDK
- Image cuối: ~10MB (chỉ chứa binary, không có SDK)
- `FROM scratch` = image rỗng (minimal)

### **Cách hoạt động:**
1. `FROM golang:1.24 AS builder` = tạo stage tên `builder` với Golang SDK
2. `COPY --from=builder /app/main .` = copy binary từ stage `builder` sang stage hiện tại
3. Docker **chỉ lưu stage cuối cùng** làm image final (stage `builder` bị discard)

### **Ví dụ: .NET Multi-stage (từ sample)**
```dockerfile
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS buildSample
WORKDIR /src
COPY . .
RUN dotnet restore
RUN dotnet publish -c Release -o /app/publish

# Stage 2: Runtime (image final)
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=buildSample /app/publish .
ENTRYPOINT ["dotnet","MyApp.dll"]
```

---

## **2.4 Build Target - Chọn Stage cụ thể**

**Khi có nhiều FROM (build stages):**
```bash
docker build -t myapp .
# → Mặc định build tới stage cuối cùng
```

**Nếu muốn build tới stage cụ thể:**
```bash
docker build --target builder -t builder-only .
# → Chỉ build tới stage "builder", không build stage runtime
```

**Ý tưởng:** 
- Debug stage intermediate (builder) mà không phải build stage final
- Hoặc export binary từ builder cho mục đích khác

---

## **2.5 Layer Caching - Tốc độ Build**

Mỗi lệnh Dockerfile (FROM, RUN, COPY) tạo 1 **layer**.

**Ví dụ:**
```dockerfile
FROM node:20           # Layer 1
WORKDIR /app           # Layer 2
COPY package.json ./   # Layer 3
RUN npm install        # Layer 4 (chậm, cài package)
COPY . .               # Layer 5 (mỗi lần source thay đổi)
RUN npm start          # Layer 6
```

**Caching:**
- Nếu layer 3,4 không thay đổi → Docker dùng cache, **không chạy lại**
- Nếu layer 5 (COPY . .) thay đổi → phải rebuild từ layer 5 trở đi

**Tối ưu:**
```dockerfile
FROM node:20
WORKDIR /app
COPY package*.json ./     # Copy chỉ package.json trước (ít thay đổi)
RUN npm install           # Cache này sẽ được tái sử dụng nhiều lần
COPY . .                  # Copy source code (hay thay đổi)
CMD ["npm", "start"]
```
- Lần build lại, nếu source code thay đổi nhưng package.json không → npm install sẽ **skip** (dùng cache)
- Tốc độ build nhanh hơn nhiều!
