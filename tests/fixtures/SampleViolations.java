import java.io.*;
import java.sql.*;
import java.util.*;

/**
 * Sample Java file with intentional code quality violations
 * for testing ast-grep rules.
 */
public class SampleViolations {

    private List<String> names = new ArrayList<>();
    private Map<String, Integer> scores = new HashMap<>();
    private int sharedCounter = 0;

    // === VIOLATION: empty catch block ===
    public void emptyCatchExample() {
        try {
            int result = 10 / 0;
        } catch (ArithmeticException e) {
        }
    }

    // === VIOLATION: broad exception catch ===
    public void broadCatchExample() {
        try {
            String data = readFile("test.txt");
        } catch (Exception e) {
            System.out.println("Something went wrong");
        }
    }

    // === VIOLATION: broad Throwable catch ===
    public void broadThrowableCatch() {
        try {
            Thread.sleep(1000);
        } catch (Throwable t) {
            t.printStackTrace();
        }
    }

    // === VIOLATION: autocloseable without try-with-resources ===
    public void resourceLeakExample() throws IOException {
        FileInputStream fis = new FileInputStream("data.bin");
        BufferedReader reader = new BufferedReader(new InputStreamReader(fis));
        String line = reader.readLine();
        reader.close(); // manual close — not exception-safe
    }

    // === GOOD: try-with-resources (should NOT trigger) ===
    public void goodResourceHandling() throws IOException {
        try (FileInputStream fis = new FileInputStream("data.bin");
             BufferedReader reader = new BufferedReader(new InputStreamReader(fis))) {
            String line = reader.readLine();
        }
    }

    // === VIOLATION: mutable collection return ===
    public List<String> getNames() {
        return names;
    }

    // === VIOLATION: mutable map return ===
    public Map<String, Integer> getScores() {
        return scores;
    }

    // === GOOD: wrapped collection return (should NOT trigger... but may due to pattern simplicity) ===
    public List<String> getSafeNames() {
        return Collections.unmodifiableList(names);
    }

    // === VIOLATION: synchronized with field assignment ===
    public void incrementCounter() {
        synchronized (this) {
            sharedCounter = sharedCounter + 1;
        }
    }

    private String readFile(String path) throws IOException {
        return new String(java.nio.file.Files.readAllBytes(java.nio.file.Paths.get(path)));
    }
}
