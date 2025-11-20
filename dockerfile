#we will write steps to build our pomodoro-app-js image

#select a BASE image

#use Nginx as BASE Image

FROM nginx

#copy code on Nginx
#use COPY module to copy code

COPY . /usr/share/nginx/html
