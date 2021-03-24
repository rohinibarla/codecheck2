name := "play-codecheck"

version := "1.0-SNAPSHOT"

maintainer := "cay@horstmann.com"

scalaVersion := "2.12.8"

lazy val root = (project in file(".")).enablePlugins(PlayJava)

libraryDependencies ++= Seq(
  guice,
  "com.amazonaws" % "aws-java-sdk" % "1.11.496",
  "net.oauth.core" % "oauth-provider" % "20100527",
  "oauth.signpost" % "signpost-core" % "1.2.1.2",
  "org.imsglobal" % "basiclti-util" % "1.1.2",   
  "com.google.cloud" % "google-cloud-secretmanager" % "1.4.0",
)

// no api docs in dist
sources in (Compile, doc) := Seq.empty

publishArtifact in (Compile, packageDoc) := false

enablePlugins(JavaAppPackaging)
enablePlugins(DockerPlugin)

dockerBaseImage := "openjdk:11"
dockerEntrypoint := Seq("bin/play-codecheck", "-Dplay.server.pidfile.path=/dev/null")

import com.typesafe.sbt.packager.docker.DockerChmodType
dockerChmodType := DockerChmodType.UserGroupWriteExecute