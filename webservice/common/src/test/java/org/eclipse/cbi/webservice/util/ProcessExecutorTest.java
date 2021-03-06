/*******************************************************************************
 * Copyright (c) 2015 Eclipse Foundation and others
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Mikaël Barbero - initial implementation
 *******************************************************************************/
package org.eclipse.cbi.webservice.util;

import static org.junit.Assert.assertEquals;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import org.junit.Test;

import com.google.common.collect.ImmutableList;

@SuppressWarnings("javadoc")
public class ProcessExecutorTest {

	@Test
	public void testEcho() throws IOException {
		StringBuilder output = new StringBuilder();
		ProcessExecutor executor = new ProcessExecutor.BasicImpl();
		int exitValue = executor.exec(ImmutableList.of("echo", "Hello World"), output, 10, TimeUnit.SECONDS);
		assertEquals(0, exitValue);
		assertEquals("Hello World\n", output.toString());
	}

}
