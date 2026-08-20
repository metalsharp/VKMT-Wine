public final class VkmtCiSmoke {
    private VkmtCiSmoke() {}

    public static void main(String[] args) {
        if (args.length != 0) {
            throw new IllegalArgumentException("unexpected arguments");
        }
        System.out.println("VKMT_JAVA_SMOKE_OK");
    }
}
