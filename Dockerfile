FROM nginx 
# Create app directory
COPY ./nginx.conf /etc/nginx/nginx.conf
RUN chmod 755 /etc/nginx/nginx.conf

EXPOSE 8080
CMD ["npm", "start"]
