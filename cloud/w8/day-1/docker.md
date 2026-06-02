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

- FROM => để cho container đó biết là sẽ cần môi trường này nếu đã có thì ko cần tải thêm về nữa, nếu chưa có thì tự động download thêm về để có đủ môi trường mà hoạt động (như node để cho js, dotnet cho c#, cargo rust, ...)
- WORKDIR => đây là điểm neo để thực hiện các lệnh tiếp theo, tạm hiểu là đang trên terminal và thực hiện lệnh "cd"
- COPY => dùng để copy các file cần thiết và docker, tạm hiểu mặc định là mọi thứ vào image (trường hợp này image = template sẵn có và có thể dễ dàng tái sử dụng), ví dụ có thể copy 1 vài file cụ thể or sử dụng "COPY .." để copy toàn bộ src (có thể sử dụng .dockerignore kèm)
- .dockerignore => như là .gitignore -> như nghĩa đen là nó sẽ ignore đi các thứ ko muốn đưa vào hay là đem theo :v
- RUN => đây là lệnh dùng để dockerfile thực hiện các lệnh khác muốn chạy như download sth or download evn or packages, libs, ...
- EXPOSE => để xác định được port sẽ sử dụng để chạy
- CMD => tạm thời tìm hiểu được thì đây là lệnh để support chạy final app, ví dụ như là dotnet run or npm start or cargo run, ...
- "docker run -p 8080:3000 myapp" => ở đây keyword chính là "-p {host-port}:{container-port} => tạm hiểu thì là host-port chính là cái cổng sẽ thực sự được sử dụng trong 1 con server đó (tạm hiểu con server này là 1 căn nhà or viện bảo tàng có nhiều lối vào -> nhiều cổng khác để ra vào), qua đó lúc này 8080 ở đây chính là cái port thực sự bị chiếm dụng đã được sử dụng, còn 3000 chỉ là 1 cái port khác bên trong container đó đang lắng nghe or xử lý chứ ko hề thực sự chiếm cái port của viện bảo tàng hay căn nhà đó! về bản chất thì 3000 này như localhost của từng máy và 8080:3000 về mặt bản chất là expose 8080 và ẩn đi cái port 3000 thực sự đc trỏ đến, khi hướng đến microservice thì có thể "nhân lên" (scale-out) nhiều container từ cùng 1 image để chạy thì mình set up sẵn thì chúng có thể là container A or B or C or container từ image có thể đang sử dụng port 3000 bên trong mà ko ảnh hưởng đến cái khác.
- 2 lần FROM => mỗi lần FROM là 1 build stage mới -> như ví dụ trên thì ở from1 có sử dụng AS -> tạo alias để nhanh chóng tìm lại or trỏ đến build stage trước đã finish để take needed info such as .dll in folder publish of dotnet chẳng hạn -> from cuối có lẽ là sẽ được tính là build stage chính và thứ mà thực sự dockerfile trả về image sau khi build xong.
- "docker build --target buildSample -t buildimg ." => giả sử có nhiều build stage (nhiều FROM) thì sẽ cần kết hợp với alias và "--target {}" để xác định image muốn build -> còn nếu k thì sẽ mặc định là sử dụng build stage cuối cùng (the last from).
