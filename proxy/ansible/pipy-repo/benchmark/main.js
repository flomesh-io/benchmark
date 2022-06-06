pipy()
    .listen(6060)
        .serveHTTP(
            msg => new Message("Hello")
        )
