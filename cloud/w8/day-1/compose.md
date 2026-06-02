# **1. example**

    services:
    api:
        build: .

    sqlserver:
        image: mcr.microsoft.com/mssql/server:2022-latest

    redis:
        image: redis:7

---

---

---

    services:

    api:
        build: .
        ports:
        - "5000:8080"

    sqlserver:
        image: mcr.microsoft.com/mssql/server:2022-latest
            environment:
                ACCEPT_EULA: "Y"

                SA_PASSWORD: "YourStrongPassword123!"

---

---

---

    project/
    │
    ├── compose/
    │ ├── docker-compose.yml
    │ ├── docker-compose.override.yml
    │ ├── docker-compose.prod.yml
    │ ├── .env
    │
    ├── src/
    │ └── MyApp/
    │ ├── Dockerfile
    │ └── ...
    │
    ├── nginx/
    │ └── nginx.conf
    │
    ├── logs/
    └── secrets/

    FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
    WORKDIR /src

    COPY . .

    RUN dotnet restore
    RUN dotnet publish -c Release -o /app/publish

    # RUNTIME
    FROM mcr.microsoft.com/dotnet/aspnet:8.0

    WORKDIR /app

    COPY --from=build /app/publish .

    EXPOSE 8080

    ENTRYPOINT ["dotnet","MyApp.dll"]

---

    version: "3.9"

    services:

        api:
            build:
                context: ../src/MyApp
                dockerfile: Dockerfile
            container_name: myapp-api

            environment:
                ASPNETCORE_URLS: http://+:8080
                ASPNETCORE_ENVIRONMENT: Production

            depends_on:
                postgres:
                    condition: service_healthy

            networks:
                - backend
                - frontend

            restart: unless-stopped

            logging:
                driver: json-file
                options:
                    max-size: "20m"
                    max-file: "5"

            healthcheck:
                test: ["CMD","curl","-f","http://localhost:8080/health"]
                interval: 30s
                timeout: 10s
                retries: 5

        postgres:
            image: postgres:16

            container_name: myapp-db

            environment:
                POSTGRES_DB: appdb
                POSTGRES_USER: appuser
                POSTGRES_PASSWORD: ${DB_PASSWORD}

            volumes:
                - postgres_data:/var/lib/postgresql/data

            networks:
                - backend

            restart: unless-stopped

            healthcheck:
                test: ["CMD-SHELL","pg_isready -U appuser"]
                interval: 10s
                timeout: 5s
                retries: 5

            logging:
                driver: json-file
                options:
                    max-size: "20m"
                    max-file: "5"

        nginx:
            image: nginx:alpine

            container_name: myapp-nginx

            depends_on:
                - api

            ports:
                - "80:80"

            volumes:
                - ../nginx/nginx.conf:/etc/nginx/nginx.conf:ro

            networks:
                - frontend

            restart: unless-stopped

    networks:
        frontend:
        backend:

    volumes:
        postgres_data:

---

    events {}

    http {

    upstream api {
        server api:8080;
    }

    server {

        listen 80;

        location / {
            proxy_pass http://api;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            }
        }
    }

---

**docker-compose.override.yml**: Dev override

    services:

        api:
            environment:
                ASPNETCORE_ENVIRONMENT: Development

            ports:
                - "5000:8080"

            volumes:
                - ../src/MyApp:/src

---

**docker-compose.prod.yml**: Prod override

    services:

        api:
            image: myregistry/myapp:1.0.0
            build: null

            environment:
            ASPNETCORE_ENVIRONMENT: Production

            deploy:
            resources:
                limits:
                cpus: "2"
                memory: 2G

        nginx:
            ports:
            - "443:443"

---

---

---

    docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    up -d

---

---

---

# **2. explanation**

- ko muốn chạy riêng lẻ thủ công từng container =>

            docker run ...
            docker run ...
            docker run ...

- thực tế là 4-5 container cùng lúc:

        ASP.NET API
            ↓
        SQL Server
            ↓
        Redis
            ↓
        RabbitMQ

- phải nhớ để chạy thủ công từng cái như là:

        docker network create backend

        docker volume create sql-data

        docker run sqlserver ...

        docker run redis ...

        docker run rabbitmq ...

        docker run api ...

- docker compose up => support tự động tạo network cho các service bên trong -> k cần tạo bridge network thủ công => thứ tự exec của compose sẽ là: Build Dockerfile -> Run container api -> Map port
- tạm hiểu bridge network như là route table
- Bản chất docker compose chính là Infrastructure as Code (IaC)
- some common command:

  - docker compose up
    Build image
    Create network
    Create volume
    Run containers
    Attach logs
  - docker compose up -d

          chạy nền do -d là detached -> khi dùng thì ko hiện ra log ngay trên terminal

  - docker compose down

          stop container
          delete container
          delete network
          STILL KEEP volume

  - docker compose down -v

          như trên nhưng xoá thêm cả VOLUME

  - docker ps

          list ra các container đang chạy

  - docker ps -a

          list ra các container đang có kể cả chạy hay không

  - docker compose logs -f

          xem logs

  - services

          mỗi con trong services sẽ tương ứng với 1 container chạy

---

    api:
        build:
            context: ../src/MyApp
            dockerfile: Dockerfile
            container_name: myapp-api


    => khi compose sẽ build image từ folder (context) bằng cách sử dụng Dockerfile ở đó và chạy với container tên là "myapp-api" <example-name>(optional -> nếu k có thì docker tự đặt tên)

---

    api:
        ...
        environment: ...
        depends_on:
            ...

        restart: unless-stopped     <- cơ chế auto-healing nếu container crash thì docker sẽ tự restart

    =>  1. nghĩa là sẽ chạy expose với port nào với env là dev hay prod
        2. depend -> khi và chỉ khi postgres HEALTHY thì api mới worked
        3. còn lại đa số là logging và network

---

    networks:
        frontend:
        backend:

    =>  1. tạo 2 bridge network là frontend và backend
        2. trong mỗi service thì có refer đến network thì đó chính là những service đó sẽ nằm trong những bridge network nào
        3. rcm hỏi lại AI xem thử đưa đoạn tạo network lên trên trước đc không hay để cuối ??

# **3. truth: Dockerfile → Docker Compose Mapping**

## **3.1 Cách Dockerfile và Docker Compose liên kết với nhau**

Dockerfile được coi là **"công thức để tạo image"** còn Docker Compose là **"công thức để chạy container từ image đó"**

### **Dockerfile → Image (Build Phase)**

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENTRYPOINT ["dotnet","MyApp.dll"]
```

### **Docker Compose → Container (Run Phase)**

```yaml
api:
  build:
    context: ../src/MyApp
    dockerfile: Dockerfile
  container_name: myapp-api
  environment:
    ASPNETCORE_URLS: http://+:8080
  ports:
    - "5000:8080"
  restart: unless-stopped
```

---

## **3.2 Chi tiết từng Keyword trong Dockerfile**

| Keyword        | Ý nghĩa                         | Giải thích                                                                                                                                                                    |
| -------------- | ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **FROM**       | Base image                      | `FROM mcr.microsoft.com/dotnet/aspnet:8.0` = Lấy hình ảnh ASP.NET 8.0 từ Microsoft Container Registry làm nền tảng. Đây là OS + runtime cơ bản mà application sẽ chạy trên đó |
| **WORKDIR**    | Thư mục làm việc                | `WORKDIR /app` = Tất cả các lệnh sau này sẽ chạy trong thư mục `/app` bên trong container. Nếu thư mục không tồn tại, Docker sẽ tạo nó                                        |
| **COPY**       | Copy file từ host vào container | `COPY --from=build /app/publish .` = Copy file từ stage `build` (quá trình build trước đó) vào thư mục hiện tại của container                                                 |
| **RUN**        | Chạy lệnh                       | `RUN dotnet restore` = Chạy lệnh để restore dependencies. Mỗi RUN tạo một layer mới trong image nên nên gộp lệnh với `&&` để giảm size                                        |
| **EXPOSE**     | Port mà container listen        | `EXPOSE 8080` = Container sẽ listen on port 8080. Đây chỉ là khai báo, không thực sự map port                                                                                 |
| **ENTRYPOINT** | Lệnh chạy khi container start   | `ENTRYPOINT ["dotnet","MyApp.dll"]` = Khi container start, nó sẽ chạy lệnh `dotnet MyApp.dll`                                                                                 |
| **ENV**        | Biến môi trường trong image     | Đặt các biến dùng trong quá trình build (không phải runtime)                                                                                                                  |

**Quan trọng**: `EXPOSE 8080` trong Dockerfile **KHÔNG MAP PORT** (không kết nối port host với container port). Nó chỉ là documentation. Port mapping thực tế được làm trong Docker Compose với `ports:`.

---

## **3.3 Chi tiết từng Keyword trong Docker Compose**

### **A. Build Section - Liên kết với Dockerfile**

```yaml
build:
  context: ../src/MyApp
  dockerfile: Dockerfile
```

- **context**: Đường dẫn chứa Dockerfile và source code. Docker sẽ tìm Dockerfile trong folder này
- **dockerfile**: Tên file Dockerfile (mặc định là `Dockerfile` nếu không chỉ định)
- **Quá trình**: Docker sẽ thực thi từng lệnh trong Dockerfile để tạo image. Mỗi lệnh (RUN, COPY, etc.) tạo một layer

### **B. Container Configuration**

```yaml
container_name: myapp-api
```

- Tên của container khi chạy (dễ nhận diện thay vì UUID)

### **C. Environment Variables - Override từ Dockerfile**

```yaml
environment:
  ASPNETCORE_URLS: http://+:8080
  ASPNETCORE_ENVIRONMENT: Production
```

- Các biến môi trường được **set tại runtime** (khi container chạy)
- Ghi đè hoặc thêm mới các ENV từ Dockerfile
- Các biến này được container process sử dụng để cấu hình hành vi

### **D. Ports - Map port từ Host → Container**

```yaml
ports:
  - "5000:8080"
```

- Format: `"HOST_PORT:CONTAINER_PORT"`
- Ánh xạ port 5000 của máy host đến port 8080 của container
- Mối liên kết với Dockerfile: `EXPOSE 8080` khai báo port mà app listen, còn `ports` làm cho port đó accessible từ ngoài

### **E. Volumes - Persistent Data + File Sharing**

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data
  - ../src/MyApp:/src
```

- **Named volume** (`postgres_data:/var/lib/postgresql/data`): Lưu dữ liệu persistent trên Docker host (ko bị mất khi container stop)
- **Bind mount** (`../src/MyApp:/src`): Mount source code từ host vào container (dùng cho development - hot reload)

### **F. Networks - Kết nối giữa các Container**

```yaml
networks:
  - backend
  - frontend
```

- Container này có thể giao tiếp với các container khác cùng network
- `api` connect vào `backend` (giao tiếp với DB) và `frontend` (giao tiếp với Nginx)
- DNS resolution tự động: `postgres` service name sẽ được resolve thành IP của postgres container

### **G. Depends_on - Thứ tự khởi động**

```yaml
depends_on:
  postgres:
    condition: service_healthy
```

- Chỉ start `api` khi `postgres` đã healthy (basedon healthcheck)
- Tránh connection error nếu app start trước khi DB sẵn sàng

### **H. Restart Policy - Tự động restart khi crash**

```yaml
restart: unless-stopped
```

- `unless-stopped`: Restart container nếu nó crash, nhưng không restart nếu manually stopped
- Giá trị khác: `no`, `always`, `on-failure`, `on-failure:max-retries`

### **I. Healthcheck - Kiểm tra container health**

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 5
```

- **test**: Lệnh kiểm tra (HTTP request đến /health endpoint)
- **interval**: Mỗi 30s check một lần
- **timeout**: Nếu không response trong 10s coi là fail
- **retries**: Fail 5 lần liên tiếp thì coi container unhealthy
- Docker Compose sử dụng healthcheck để quyết định `depends_on` condition

### **J. Logging - Control log driver**

```yaml
logging:
  driver: json-file
  options:
    max-size: "20m"
    max-file: "5"
```

- **driver**: `json-file` = lưu logs dưới dạng JSON files
- **max-size**: Mỗi file log max 20MB
- **max-file**: Giữ tối đa 5 file log (rotation)
- Tránh logs chiếm quá nhiều disk space

---

## **3.4 Flow từ Dockerfile đến Docker Compose Runtime**

### **Bước 1: Build Image (Docker reads Dockerfile)**

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0  ← Layer 1: Base OS
WORKDIR /app                               ← Layer 2: Directory
COPY --from=build /app/publish .           ← Layer 3: Copy files
EXPOSE 8080                                ← Layer 4: Metadata (port declaration)
ENTRYPOINT ["dotnet","MyApp.dll"]          ← Layer 5: Default command
```

**Kết quả**: Image với định danh (tag/ID) ví dụ `myapp:latest`

### **Bước 2: Run Container (Docker reads Compose)**

```yaml
api:
  build:
    context: ../src/MyApp
    dockerfile: Dockerfile
```

- Compose nhìn thấy `build` → tìm Dockerfile → execute các layer → tạo image
- Nếu image đã tồn tại, có thể skip build và dùng `image:` thay vì `build:`

```yaml
ports:
  - "5000:8080"
```

- Port 8080 từ `EXPOSE` được map thành 5000 trên host
- Traffic từ `localhost:5000` được forward vào `container:8080`

```yaml
environment:
  ASPNETCORE_URLS: http://+:8080
```

- Set biến môi trường runtime (không phải build-time)
- App bên trong container sẽ đọc `ASPNETCORE_URLS` và hi HTTP server listen on `+:8080` (tất cả interfaces)

```yaml
depends_on:
  postgres:
    condition: service_healthy
```

- Compose chờ postgres healthcheck pass trước khi start api
- Api container sẽ run `ENTRYPOINT ["dotnet","MyApp.dll"]` từ Dockerfile
- Lệnh này (dotnet app) sẽ chạy với các ENV variables từ compose

### **Bước 3: Network Communication**

- Docker tạo bridge network `backend` và `frontend`
- Api container được attach vào cả 2 networks
- Có thể gọi `postgres:5432` (service name:port) để kết nối DB
- Nginx gọi `api:8080` (service name:port) để proxy request

---

## **3.5 Phân biệt: Build-time vs Runtime**

| Thời điểm      | Dockerfile Command     | Docker Compose                 | Kết quả                           |
| -------------- | ---------------------- | ------------------------------ | --------------------------------- |
| **Build-time** | `RUN dotnet restore`   | N/A                            | Dependency được cài vào image     |
| **Build-time** | `RUN dotnet publish`   | N/A                            | Binary được compile vào image     |
| **Runtime**    | `ENTRYPOINT`           | `command:` override            | Lệnh thực thi khi container start |
| **Runtime**    | `ENV APP_NAME=default` | `environment: APP_NAME=custom` | Biến được override bởi compose    |
| **Build-time** | `EXPOSE 8080`          | `ports: "5000:8080"`           | Declaration + mapping             |

**Quan trọng**: Những gì trong Dockerfile là tĩnh (cố định trong image). Những gì trong Compose là động (có thể thay đổi mỗi lần chạy container).

---

## **3.6 Ví dụ thực tế: Development vs Production**

### **docker-compose.yml (Base)**

```yaml
api:
  build:
    context: ../src/MyApp
    dockerfile: Dockerfile
  environment:
    ASPNETCORE_ENVIRONMENT: Production
  ports:
    - "5000:8080"
```

### **docker-compose.override.yml (Dev Override)**

```yaml
api:
  environment:
    ASPNETCORE_ENVIRONMENT: Development  ← Ghi đè thành Development
  volumes:
    - ../src/MyApp:/src                  ← Mount source code cho hot reload
```

**Khi chạy locally**:

- `docker compose up` sẽ merge cả 2 file
- App chạy Development mode với source code mounted
- Có thể sửa code → app tự reload (nếu app support)

### **docker-compose.prod.yml (Prod Override)**

```yaml
api:
  image: myregistry/myapp:1.0.0          ← Dùng pre-built image từ registry
  build: null                             ← Không build, chỉ dùng image
  environment:
    ASPNETCORE_ENVIRONMENT: Production
  deploy:
    resources:
      limits:
        cpus: "2"
        memory: 2G
```

**Khi chạy production**:

- `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`
- Dùng pre-built image (nhanh hơn không phải build)
- Limit CPU/Memory resources
- Chạy detached (nền)

---

## **3.7 Validation: Section 2 Review**

**Đúng**: "docker compose up => support tự động tạo network cho các service"

- Đúng, compose tạo bridge network tên `{PROJECT_NAME}_{NETWORK_NAME}` (ví dụ `myproject_backend`)

  **Đúng**: "tạm hiểu bridge network như là route table"

- Chính xác, bridge network routing traffic giữa các container

  **Đúng**: "Bản chất docker compose chính là Infrastructure as Code (IaC)"

- 100% đúng, define infra (network, volume, service dependencies) dưới dạng YAML

  **Cần thêm nuance**: "thứ tự exec của compose sẽ là: Build Dockerfile -> Run container api -> Map port"

- Thêm chính xác hơn:
  1. Resolve dependencies (read all services)
  2. Build images (từ `build:` section)
  3. Create networks
  4. Create volumes
  5. Run containers theo thứ tự (với respect tới `depends_on`)
  6. Map ports
  7. Attach logging

**Điều cần chú ý**: `depends_on` không guarantee thứ tự, chỉ guarantee _container start trước_. Nó không chờ service thực sự ready (trừ khi có `condition: service_healthy`).
