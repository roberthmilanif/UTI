# Stage 1: Build the React application
FROM node:18-alpine AS build

WORKDIR /app

# Copy package.json and package-lock.json (or yarn.lock)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application source code
COPY . .

# Build the application
RUN npm run build

# Stage 2: Serve the application using Nginx
FROM nginx:stable-alpine AS production

# Copy the build output from the build stage to Nginx's web root directory
COPY --from=build /app/build /usr/share/nginx/html

# Remove default Nginx server configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy our custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/custom-nginx.conf
# Note: Renamed to custom-nginx.conf to be more specific, standard practice.
# If nginx.conf was intended to be the only conf, it could replace default.conf or be named site.conf etc.

# Expose port 80
EXPOSE 80

# Start Nginx when the container launches
CMD ["nginx", "-g", "daemon off;"]
