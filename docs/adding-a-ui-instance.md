## Adding a digitransit-ui instance

Provided that a new Digitransit region is located in Baden-Württemberg, you need to follow the following steps
to host a new installation:

- Create a configuration and colour scheme in `stadtnavi/digitransit-ui`: https://github.com/stadtnavi/digitransit-ui/commit/3531498bb03ddd6f1356c38626ac5b7b92ab363f

- Edit the variable `digitransit_ui` and add a the configuration name, domain, 
  and port: https://github.com/stadtnavi/digitransit-ansible/blob/0af0aa81bed78fd817ef45cf85840b3a4dcd511b/group_vars/ludwigsburg.yml#L4-L10

- Configure the variable `certbot_certs`: https://github.com/stadtnavi/digitransit-ansible/blob/0af0aa81bed78fd817ef45cf85840b3a4dcd511b/group_vars/ludwigsburg.yml#L26-L34 

