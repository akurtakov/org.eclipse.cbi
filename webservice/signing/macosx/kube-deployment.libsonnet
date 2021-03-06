local newDeployment() = {
  route: {
    apiVersion: "route.openshift.io/v1",
    kind: "Route",
    metadata: {
      annotations: {
        "haproxy.router.openshift.io/timeout": "600s",
        "haproxy.router.openshift.io/rewrite-target": "/macosx-signing-service"
      },
      name: "macos-codesign",
      namespace: "foundation-internal-infra-apps"
    },
    spec: {
      host: "cbi.eclipse.org",
      path: "/macos/codesign/sign",
      port: {
        targetPort: "http"
      },
      tls: {
        insecureEdgeTerminationPolicy: "Redirect",
        termination: "edge"
      },
      to: {
        kind: "Service",
        name: "macos-codesign",
        weight: 100
      },
    }
  },
  service: {
    apiVersion: "v1",
    kind: "Service",
    metadata: {
      name: "macos-codesign",
      namespace: "foundation-internal-infra-apps"
    },
    spec: {
      type: "ClusterIP",
      ports: [
        {
          name: "http",
          port: 80,
          protocol: "TCP",
          targetPort: 8282
        }
      ],
    }
  },
  endpoints: {
    apiVersion: "v1",
    kind: "Endpoints",
    metadata: {
      name: "macos-codesign",
      namespace: "foundation-internal-infra-apps"
    },
    subsets: [
      {
        addresses: [
          {
            ip: "172.30.206.145"
          },
          {
            ip: "172.30.206.146"
          },
        ],
        ports: [
          {
            name: "http",
            port: 8282,
            protocol: "TCP"
          }
        ]
      }
    ]
  },
  "kube.yml": std.manifestYamlStream([$.route, $.service, $.endpoints], true, c_document_end=false),
};
{
  newDeployment:: newDeployment,
}

