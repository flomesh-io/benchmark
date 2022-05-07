pipy({
  _router: new algo.URLRouter({
    '/1': new Data(new Array(1024).fill(65)),
    '/10': new Data(new Array(10*1024).fill(65)),
    '/100': new Data(new Array(100*1024).fill(65)),
    '/1000': new Data(new Array(1000*1024).fill(65)),
    '/*': new Data(new Array(128).fill(65))
  })
})

.listen(8080)
  .serveHTTP(
    req => new Message(
      _router.find(req.head.path)
    )
  )
