/*
Copyright 2019 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package sanity

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"

	"github.com/kubernetes-csi/csi-test/pkg/sanity"
	"sigs.k8s.io/amlfs-csi-driver/pkg/amlfs"
)

func TestSanity(t *testing.T) {
	testDir, err := ioutil.TempDir("", "csi_sanity_test")
	if err != nil {
		t.Fatalf("can't create tmp dir %s", err)
	}
	socketEndpoint := filepath.Join(testDir, "csi.sock")
	targetPath := filepath.Join(testDir, "targetPath")
	stagingPath := filepath.Join(testDir, "stagingPath")
	socketEndpoint = "unix://" + socketEndpoint
	config := &sanity.Config{
		Address:          socketEndpoint,
		TargetPath:       targetPath,
		StagingPath:      stagingPath,
		CreateTargetDir:  createDir,
		CreateStagingDir: createDir,
		TestVolumeParameters: map[string]string{
			amlfs.VolumeContextMDSIPAddress: "127.0.0.1",
			amlfs.VolumeContextFSName:       "test",
		},
	}
	driverOptions := amlfs.DriverOptions{
		NodeID:               "fakeNodeID",
		DriverName:           "fake",
		EnableAmlfsMockMount: false,
	}
	driver := amlfs.NewDriver(&driverOptions)
	go func() {
		driver.Run(socketEndpoint, "", true)
	}()
	sanity.Test(t, config)
}

func createDir(targetPath string) (string, error) {
	fmt.Println("---- path content ----")
	files, err := ioutil.ReadDir(filepath.Dir(targetPath))
	if err != nil {
		fmt.Println(err)
	}
	fmt.Println("**** path content ****")

	for _, file := range files {
		fmt.Println(file.Name(), file.IsDir())
	}
	fmt.Printf("===: building %s\n", targetPath)
	if err := os.MkdirAll(targetPath, 0300); err != nil {
		if os.IsNotExist(err) {
			return "", err
		}
	}
	return targetPath, nil
}
