locals {
  name = var.env != "" ? "${var.component_name}-${var.env}" : var.component_name
  db_commands = [
    "rm -rf Roboshop-shell",
    "git clone https://github.com/PranathiAT/Roboshop-shell.git",
    "cd Roboshop-shell",
    "sudo bash ${var.component_name}.sh ${var.password}"
  ]
  app_commands = [
#    "sudo labauto ansible",
#    "ansible-pull -i localhost, -U https://github.com/PranathiAT/roboshop-ansible roboshop.yml -e env=${var.env} -e role_name=${var.component_name}"
      "echo hi"
  ]
}
