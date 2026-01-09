{...}let

  accessKey = "nextcloud";
  secretKey = "test12345";

  rootCredentialsFile = pkgs.writeText "minio-credentials-full" ''
    MINIO_ROOT_USER=nextcloud
    MINIO_ROOT_PASSWORD=test12345
  '';

in

{
environment.etc."nextcloud-admin-pass".text = "PWD";
services.nextcloud = {
  enable = true;
  package = pkgs.nextcloud31;
  hostName = "cloud.thethalium.ch";
  configureRedis = true;
  config.adminpassFile = "/etc/nextcloud-admin-pass";
  config.dbtype = "sqlite";
  config.objectstore.s3 = {
      enable = true;
      bucket = "nextcloud";
      autocreate = true;
      key = accessKey;
      secretFile = "${pkgs.writeText "secret" "test12345"}";
      hostname = "localhost";
      useSsl = false;
      port = 9000;
      usePathStyle = true;
      region = "us-east-1";
    };
extraApps = {
    inherit (config.services.nextcloud.package.packages.apps) news contacts calendar tasks;
  };
  extraAppsEnable = true;
};
}
