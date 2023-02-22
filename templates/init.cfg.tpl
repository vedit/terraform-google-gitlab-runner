# cloud-config
users:
  - name: gitlab-runner
    shell: /bin/bash
    uid: 2000
    groups:
      - docker

write_files:
  - path: /etc/gitlab-runner/config.toml
    owner: root:root
    permissions: '0644'
    content: |
      # Prometheus metrics at /metrics, also used for health checks.
      listen_address = ":${hc_port}"
      concurrent = ${concurrent}
  - path: /var/run/gitlab-runner-register
    permissions: 0600
    owner: root
    content: |
      REGISTRATION_TOKEN=${registration_token}
  - path: /etc/systemd/system/gitlab-runner-register.service
    permissions: 0644
    owner: root
    content: |
      [Unit]
      Description=GitLab Runner Registration/Unregistration
      ConditionFileIsExecutable=/var/lib/google/bin/gitlab-runner
      After=syslog.target network-online.target
      [Service]
      EnvironmentFile=/var/run/gitlab-runner-register
      Type=oneshot
      RemainAfterExit=yes
      ExecStart=/var/lib/google/bin/gitlab-runner "register" "--non-interactive" "--url" "${gitlab-url}" "--executor" "docker" --docker-image alpine:latest --tag-list "${tag-list}" --run-untagged="true" --locked="false" --access-level="not_protected"  --docker-pull-policy "if-not-present" --docker-privileged
      ExecStop=/var/lib/google/bin/gitlab-runner "unregister" "--config" "/etc/gitlab-runner/config.toml" "--all-runners"
      [Install]
      WantedBy=multi-user.target
  - path: /etc/systemd/system/gitlab-runner.service
    permissions: 0644
    owner: root
    content: |
      [Unit]
      Description=GitLab Runner
      ConditionFileIsExecutable=/var/lib/google/bin/gitlab-runner
      After=gitlab-runner-register.service syslog.target network-online.target
      Requires=gitlab-runner-register.service
      [Service]
      StartLimitInterval=5
      StartLimitBurst=10
      ExecStart=/var/lib/google/bin/gitlab-runner "run" "--working-directory" "/home/gitlab-runner" "--config" "/etc/gitlab-runner/config.toml" "--service" "gitlab-runner" "--syslog" "--user" "gitlab-runner"
      Restart=always
      RestartSec=120
      [Install]
      WantedBy=multi-user.target

runcmd:
  - mkdir /var/lib/google/tmp
  - mkdir /var/lib/google/bin
  - mount -o size=129K -t tmpfs none /root/
  - curl -L --output /var/lib/google/tmp/gitlab-runner ${gitlab-runner-url}
  - install -o 0 -g 0 -m 0755 /var/lib/google/tmp/gitlab-runner /var/lib/google/bin/gitlab-runner
  - systemctl daemon-reload
  - systemctl start gitlab-runner-register.service
  - systemctl start gitlab-runner.service
