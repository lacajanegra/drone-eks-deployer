#!/bin/sh

# On error, exit immediately
set -e

echo "Initializing..."

if [ -z ${PLUGIN_AWS_REGION} ]; then
    export PLUGIN_AWS_REGION="us-east-1"
fi
export AWS_DEFAULT_REGION=${PLUGIN_AWS_REGION}
echo "region ${AWS_DEFAULT_REGION}"

echo $(aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID)
echo $(aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY)
echo $(aws configure set region $PLUGIN_AWS_REGION)

export NODE_GROUP_ARN=${PLUGIN_NODE_ROLE}

export CLUSTER_NAME=$(echo "${PLUGIN_CLUSTER}" | cut -d"/" -f2)

echo ""
echo "Trying to deploy against '$CLUSTER_NAME' ($AWS_DEFAULT_REGION) $NODE_GROUP_ARN."
echo ""


echo "Fetching the authentication token..."
KUBERNETES_TOKEN=$(aws-iam-authenticator token -i $CLUSTER_NAME -r $NODE_GROUP_ARN | jq -r .status.token)

if [ -z $KUBERNETES_TOKEN ]; then
    echo ""
    echo "Unable to obtain Kubernetes token - check Drone's IAM permissions"
    echo "Maybe it cannot assume the '$NODE_GROUP_ARN' role?"
    exit 1
fi


echo "Fetching the EKS cluster information..."
EKS_URL=$(aws eks describe-cluster --name $CLUSTER_NAME | jq -r .cluster.endpoint)
EKS_CA=$(aws eks describe-cluster --name $CLUSTER_NAME | jq -r .cluster.certificateAuthority.data)

if [ -z $EKS_URL ] || [ -z $EKS_CA ]; then
    echo ""
    echo "Unable to obtain EKS cluster information - check Drone's EKS API permissions"
    exit 1
fi

echo "Succesfull FEKS cluster information ${EKS_URL}"


echo "Generating the k8s configuration file..."
if [ -d  ~/.kube ]; 
then 
   echo "~/.kube exists"
else
   mkdir ~/.kube
fi

cat > ~/.kube/config << EOF
apiVersion: v1

clusters:
- cluster:
    server: ${EKS_URL}
    certificate-authority-data: ${EKS_CA}
  name: ${PLUGIN_CLUSTER}

contexts:
- context:
    cluster: ${PLUGIN_CLUSTER}
    user: ${PLUGIN_CLUSTER}
  name: ${PLUGIN_CLUSTER}

current-context: ${PLUGIN_CLUSTER}
preferences: {}
kind: Config
users:
- name: ${PLUGIN_CLUSTER}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws
      args:
      - --region
      - us-east-1
      - eks
      - get-token
      - --cluster-name
      - $CLUSTER_NAME
EOF

echo "Exporting k8s configuration path..."
export KUBECONFIG=$KUBECONFIG:~/.kube/config


echo $(aws eks --region $AWS_DEFAULT_REGION update-kubeconfig --name $CLUSTER_NAME --role-arn $NODE_GROUP_ARN)

echo "Applying the manifest..."
echo ""
cat ".kube.yml" | sed 's@__TAG__@'"$DRONE_TAG"'@g' | kubectl apply -f -
echo ""
echo "Flow has ended."
