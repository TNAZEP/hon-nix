{
  flake.nixosModules.java = { pkgs, ... }: {
    programs.java = {
      enable = true;
      package = pkgs.zulu25;
    };
    # Keep older JDKs accessible without competing for bin/java and bin/javac.
    environment.etc = {
      "jdks/8".source = pkgs.zulu8;
      "jdks/17".source = pkgs.zulu17;
      "jdks/21".source = pkgs.zulu21;
      "jdks/25".source = pkgs.zulu25;
    };
    environment.variables = {
      JAVA_8_HOME = "/etc/jdks/8";
      JAVA_17_HOME = "/etc/jdks/17";
      JAVA_21_HOME = "/etc/jdks/21";
      JAVA_25_HOME = "/etc/jdks/25";
    };
  };
}
