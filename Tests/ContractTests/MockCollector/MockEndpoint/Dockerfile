
FROM node:18-alpine

WORKDIR /app

COPY server.js .

EXPOSE 8080

# Set Node.js to run in production mode
ENV NODE_ENV=production

# Disable keep-alive connections
ENV NODE_NO_HTTP_KEEP_ALIVE=1

# Set a shorter stop timeout (3 seconds)
STOPSIGNAL SIGTERM

CMD ["node", "server.js"]
