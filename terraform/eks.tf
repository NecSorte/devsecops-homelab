module "eks" {
  # missing ebs
  source             = "terraform-aws-modules/eks/aws"
  version            = "~> 21.0"
  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  subnet_ids         = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id

  # Why?
  endpoint_public_access                   = true
  endpoint_private_access                  = true
  endpoint_public_access_cidrs             = ["50.191.250.169/32"]
  enable_cluster_creator_admin_permissions = true


  # Failure to create the CNI add-on prevents node group creation.
  addons = {
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {}
    coredns    = {}
    # Added Missing esb 
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }
  }

  # Node group configuration
  eks_managed_node_groups = {
    default = {
      desired_size   = var.node_desired_capacity
      min_size       = 1
      max_size       = var.node_max_capacity
      instance_types = [var.node_instance_type]

      # Instance type configuration
      capacity_type = var.use_spot_instances ? "SPOT" : "ON_DEMAND"

      # Security improvements
      ami_type = "AL2023_x86_64_STANDARD"

      # Node group configuration
      disk_size = 20

      # Labels
      labels = {
        Environment = "interview"
        Purpose     = "devsecops-lab"
      }
    }
  }

  tags = {
    Environment = "eks-interview-lab"
    Terraform   = "true"
    Purpose     = "devsecops-interview"
  }
}
