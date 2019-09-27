FROM swift:5.1 as builder

RUN apt-get -qq update && apt-get -q -y install \
  tzdata \
  libssl-dev \
  zlib1g-dev \
  && rm -r /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN mkdir -p /build/lib && cp -R /usr/lib/swift/linux/*.so* /build/lib
RUN swift build -c release -Xswiftc -g && mv `swift build -c release -Xswiftc -g --show-bin-path` /build/bin

# Production image
FROM ubuntu:18.04
ARG env
RUN apt-get -qq update && apt-get install -y \
  libicu60 libxml2 libbsd0 libcurl3 libatomic1 \
  tzdata \
  && rm -r /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /build/bin/Run .
COPY --from=builder /build/lib/* /usr/lib/
COPY --from=builder /app/Public ./Public
COPY --from=builder /app/Resources ./Resources

ENTRYPOINT ./Run serve --hostname 0.0.0.0 --port 80
