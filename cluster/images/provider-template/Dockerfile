FROM gcr.io/distroless/static@sha256:4ff820db6d801f22e99436d783fdf954d22a4b5df6f3bd742d4df8a35ad12bfa

ARG TARGETOS
ARG TARGETARCH

ADD bin/$TARGETOS\_$TARGETARCH/provider /usr/local/bin/crossplane-template-provider

USER 65532
ENTRYPOINT ["crossplane-template-provider"]
