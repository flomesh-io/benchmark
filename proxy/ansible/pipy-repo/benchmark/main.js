pipy()
    .listen(8080)
        .serveHTTP(
            msg => new Message("Hello\n")
        )
