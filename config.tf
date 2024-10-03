terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.6"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-b"
}

resource "null_resource" "create_build_key" {
  provisioner "local-exec" {
    command = "ssh-keygen -b 2048 -f ${path.module}/build"
  }
}

resource "local_file" "build_private_key" {
  filename = "${path.module}/build"
  depends_on = [null_resource.create_build_key]
}

resource "local_file" "build_public_key" {
  filename = "${path.module}/build.pub"
  depends_on = [null_resource.create_build_key]
}

resource "null_resource" "create_deploy_key" {
  provisioner "local-exec" {
    command = "ssh-keygen -b 2048 -f ${path.module}/deploy"
  }
}

resource "local_file" "deploy_private_key" {
  filename = "${path.module}/deploy"
  depends_on = [null_resource.create_deploy_key]
}

resource "local_file" "deploy_public_key" {
  filename = "${path.module}/deploy.pub"
  depends_on = [null_resource.create_deploy_key]
}

resource "yandex_compute_instance" "build" {

  name = "build"

  zone = "ru-central1-b"
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd874d4jo8jbroqs6d7i"
    }
  }

  network_interface {
    subnet_id = "e2lgv5mqm56n8fjkt37q"
    nat = true
  }

  metadata = {
    ssh-keys = local_file.build_public_key.content
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y git maven",
      "cd /tmp && git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello.git",
      "cd /tmp/boxfuse-sample-java-war-hello && mvn package"
    ]
    connection {
      host = self.network_interface.0.nat_ip_address
      type = "ssh"
      user = "ubuntu"
      private_key = local_file.build_private_key.content
    }

  }

}

resource "yandex_compute_instance" "deploy" {

  name = "deploy"

  zone = "ru-central1-b"
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd874d4jo8jbroqs6d7i"
    }
  }

  network_interface {
    subnet_id = "e2lgv5mqm56n8fjkt37q"
    nat = true
  }

  metadata = {
    ssh-keys = local_file.deploy_public_key.content
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y tomcat9"
    ]
    connection {
      host = self.network_interface.0.nat_ip_address
      type = "ssh"
      user = "ubuntu"
      private_key = local_file.build_private_key.content
    }

  }

}
