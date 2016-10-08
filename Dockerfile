FROM sameersbn/gitlab:8.12.3

MAINTAINER birk@pingworks.de

ENV HOOKS_GITLAB_REPOS_PATH=/home/git/data/repositories \
    HOOKS_CONFIG_URL=/opt/jenkinshooks/hooks_config.yml \
    HOOKS_TPL_URL=/opt/jenkinshooks/post-receive.erb \
    HOOKS_LOG=/var/log/jenkinshooks.log \
    HOOKS_DEBUG=0

COPY create_hooks.rb hooks_config.yml post-receive.erb /opt/jenkinshooks/
COPY jenkinshooks-cron.sh /etc/cron.d/jenkinshooks
COPY entrypoint.sh /sbin/entrypoint2.sh
RUN chmod 755 /sbin/entrypoint2.sh

RUN gem install --no-ri --no-rdoc erubis \
    && touch /var/log/jenkinshooks.log \
    && chmod 755 /etc/cron.d/jenkinshooks \
    && chmod 755 /opt/jenkinshooks/create_hooks.rb

ENTRYPOINT ["/sbin/entrypoint2.sh"]
CMD ["app:start"]
